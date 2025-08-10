// construct quarterly compustat 

clear 
global maindir "/Users/kenteoh/Dropbox/debt_covenant"
global rawdir "$maindir/rawdata_jfi_fin"
global datdir "$maindir/data_jfi_fin"

* -------------------------------------------------------
* import data here 
use "$rawdir/wrds/compustat_fundq_00-20", clear 
drop index
gen cusip6 = substr(cusip,1,6)
keep if fic == "USA"
replace cusip = substr(cusip,1,8)

loc varlist datadate rdq 
foreach var in `varlist' {
	gen tmp = dofc(`var')
	format %td tmp
	drop `var'
	rename tmp `var'
}

* if missing fqtr, replace with quarter of data date
replace fqtr = quarter(datadate) if missing(fqtr)

* this is user generated from fyearq fqtr 
gen datefq = yq(fyearq,fqtr)
format %tq datefq

gen datecq = yq(year(datadate), quarter(datadate))
format %tq datecq 

* manage duplicates 
bys gvkey datadate (fyearq): keep if _n == _N 	 
	* drop duplicate data date, keep latest fiscal year (duplicates due to changing fiscal year)
bys gvkey fyearq fqtr (datadate): keep if _n == 1 
	* keep oldest fiscal quarter if duplicate 

* reporting quarter -- set to be next quarter following fiscal end if missing
replace rdq = datadate + 1 if missing(rdq)
gen daterq = yq(year(rdq), quarter(rdq))
format %tq daterq 

* merge with hq information
* note: can replace this with hq info from header files
preserve 
	use "$rawdir/wrds/compustat_fundq_address", clear 

	* manage duplicates 
	bys gvkey datadate: keep if _n == _N 	 // drop duplicate data date			

	keep gvkey datadate state
	
	tempfile add
	save `add'
restore 
merge 1:1 gvkey datadate using `add', keep(1 3) nogen

* merge with annual information from funda
preserve 
	use gvkey datadate fyear sich ds xrent dvc xrd emp at xintopt capx ebitda sale mib  mrc* rouant ///
		using "$rawdir/wrds/compustat_funda_00-20", clear
	
	bys gvkey fyear (datadate): keep if _n == 1
	drop datadate

	rename fyear fyearq 
	
	encode gvkey, gen(firm_id)
	xtset firm_id fyearq
	
	* clean data
	replace at = . if at < 0
	replace sale = . if sale < 0
	
	* operating lease (see Lim Mann Mihov 2017)
	forval i = 1/5 {
		gen mrc`i'_pv = mrc`i'/(1.08^`i')
	}
	gegen aux = rowtotal(xrent mrc1_pv mrc2_pv mrc3_pv mrc4_pv mrc5_pv)
	gen oplease_sp_yr = aux / l1.at if aux!=0
	drop aux
	gen aux = (xrent + mrc1) / 2 / (0.08)
	gen oplease_perp_yr = aux / l1.at if aux!=0
	drop aux

	* annual variables 
	gen optioncomp_yr = xintopt / l1.at
	gen capx_yr = capx / l1.at  
	gen opebitda_yr = ebitda / l1.at 
	gen saleat_yr = sale / l1.at
	gen size_yr = ln(at)
	gen mibat_yr = mib / l1.at
	gen rouant_yr = rouant / l1.at
	gen employment_yr = emp / l1.at * 1000
	
	* employment growth 
	gen emp_growth = (emp - l1.emp) / l1.emp 
	
	keep gvkey fyearq *_yr emp_growth sich
	
	tempfile sich 
	save `sich'
restore 
merge m:1 gvkey fyearq using `sich', keep(1 3) nogen

bys gvkey (datefq): carryforward sich fic, replace
gsort gvkey -datefq
by gvkey: carryforward sich fic, replace
gsort gvkey datefq 

* merge with fama french industry classificaiton 
preserve 
	use "$rawdir/misc/my_cusip_ffind12_xwalk.dta", clear
		* from macro_attn/code/0_0_pull_data/gen_cusip_ffind12_xwalk.do
	drop if missing(ff_ind_12)
	gduplicates drop cusip, force
	drop sic
	
	replace cusip = substr(cusip, 1, 8)
	
	tempfile xwalk
	save `xwalk'
restore 
merge m:1 cusip using `xwalk', keep(1 3) nogen

* merge with capital iq variables 
merge m:1 gvkey fyearq fqtr using "$datdir/CapIQ_CreditLine_Vars_processed", keep(1 3) nogen

* merge with producer price index
preserve 
	use "$rawdir/misc/fred_macro_series", clear 
	keep datecq dppi_capex 
	tempfile fred 
	save `fred'
restore 
merge m:1 datecq using `fred', keep(1 3) nogen 
	
* -------------------------------------------------------
* housekeeping

* measurement error 
replace saleq = . if saleq < 0 
replace prc = . if abs(prc) < 1
replace atq = . if atq < 0
replace cheq = . if cheq < 0
replace xsgaq = . if xsgaq < 0
// replace seqq = . if seqq < 0 

* correction for operating lease 
* see https://cpb-us-w2.wpmucdn.com/voices.uchicago.edu/dist/7/1291/files/2017/01/lease.pdf
* added April 28, 2023
replace atq = atq - rouantq
replace ppentq = ppentq - rouantq 
replace dlttq = dlttq - llltq
replace dlcq = dlcq - llcq
replace ltq = ltq - (llltq + llcq)
replace lctq = lctq - llcq

* interpolate stock variables 
loc varlist dlttq dlcq atq ltq ppentq cheq
foreach var in `varlist' {
	bys gvkey (datefq): ipolate `var' datefq, gen(tmp)
	drop `var'
	rename tmp `var'
}

* industry sic code
tostring sich, gen(sich_str)
gen sic2 = substr(sich_str,1,2)
destring sic2, replace

* set variables to zero if missing (for selected variables)
loc varlist xintq
foreach var in `varlist' {
	replace `var' = 0 if missing(`var')
}

* -------------------------------------------------------
* construct variables 

encode gvkey, gen (firm_id)
xtset firm_id datefq 

* debt and equity financing 
gen prstkcq=prstkcy-l.prstkcy
replace prstkcq=prstkcy if fqtr==1

gen sstkq=sstky-l.sstky
replace sstkq=sstky if fqtr==1

gen dltisq=dltisy-l.dltisy
replace dltisq=dltisy if fqtr==1
gen dltrq=dltry-l.dltry
replace dltrq=dltry if fqtr==1               

gen netdebt=dltisq-dltrq				
replace netdebt=dltisq if  dltrq==.
replace netdebt=-dltrq if  dltisq==.

gen netequity=prstkcq-sstkq			
replace netequity=prstkcq if sstkq==.
replace netequity=-sstkq if  prstkcq==.
		
gen debt = dlttq+dlcq
gen debt_minus_cash = dlttq+dlcq-cheq

gen avg_asset = (atq + l1.atq) /2
gen net_asset = atq - cheq

gen dvq = dvy-l1.dvy
replace dvq = dvy if fqtr==1
// replace dvq = 0 if missing(dvq) //replace missing dividend payment with zero
	// removed October 20, 2024

* capital expenditures 
gen capxq = capxy-l.capxy
replace capxq = capxy if fqtr==1

* cash flow
gen oancfq = oancfy - l.oancfy
replace oancfq = oancfy if fqtr==1

gen ibcq = ibcy - l1.ibcy 
replace ibcq = ibcy if fqtr==1

* acquisition
gen acq=aqcy-l.aqcy
replace acq=aqcy if fqtr==1

* interest payment 
gen intpnq=intpny-l.intpny
replace intpnq=intpny if fqtr==1

* deferred taxes
gen txdcq = txdcy-l1.txdcy 
replace txdcq=txdcy if fqtr==1

* r&d expense (handle missing data)
replace xrdq = . if xrdq < 0 // replace negative r&d as missing 
gen xrdq_ind = !missing(xrdq)
bys firm_id (datefq): gen aux = xrdq_ind[1] if _n==1
by firm_id: replace aux = max(xrdq_ind, aux[_n-1]) if missing(aux)
gegen any_aux = max(aux), by(firm_id fyearq) // handle cases where rd spend reported end of year
gen xrdq_adj = xrdq
replace xrdq_adj = 0 if any_aux==1 & missing(xrdq_adj)
drop aux any_aux 

* compute ppe by perpetual inventory (see Stein and Stone 2013)
bys firm_id (datefq): gen ppentq0 = ppentq if _n==1 
gen ppe_discount = (1-0.1)^(1/4)
bys firm_id (datefq): replace ppentq0 = dppi_capex*ppe_discount*ppentq0[_n-1]+capxq if _n>1
replace ppentq0 = . if ppentq0 <0
drop ppe_discount

* normalized variables 
gen net_debt_issuance 	= netdebt / l1.atq 
gen net_debt_issuance_ppe = netdebt / l1.ppentq
gen net_equity_issuance = netequity / l1.atq
gen equitypay           = (prstkcq+dvq) / l1.atq
gen capx_spend 			= capxq / l1.atq 				// capital expendiure
gen capx_spend_ppe 		= capxq / l1.ppentq
gen capx_spend_perp 	= capxq / l1.ppentq0
gen capx_spend_aa       = capxq / avg_asset	
gen rd_spend 			= xrdq_adj / l1.atq 				// r&d spending
gen opebitda 			= oibdpq / l1.atq 				// operating earnings ebitda
gen opebitda_aa			= oibdpq / avg_asset
gen saleatq 			= saleq / l1.atq
gen ncocf 				= (oancfq + xintq) / l1.atq 	// net operating cash flows
gen ncocf_aa 			= (oancfq + xintq) / avg_asset
gen mcap 				= abs(prc) * shrout / 1000
gen tobinq 				= (dlttq + dlcq + mcap) / atq
gen cashhold	 		= cheq / atq 					// cash holding
gen cashhold_na			= cheq / net_asset
gen ppe					= ppentq / atq 					// ppe
gen ppe_perp 			= ppentq0 / atq 				// ppe (perpetual inventory)
gen invent 				= invtq / atq 					// inventory
gen receiv				= rectq / atq 					// receivable 
gen depre				= dpq / l1.atq 					// depreciation
gen margin 				= oibdpq / saleq				// margin 
gen size 				= log(atq)						// size
gen acquisitions		= acq / l1.atq 					// acquisitions
gen acquisitions_aa = acq / avg_asset
gen netincome 			= niq / l1.atq 					// net income 
gen intexpense 			= xintq / l1.atq 				// interest expense 
gen intexpense_aa 		= xintq / avg_asset 
gen networth 			= (atq - ltq) / atq 			// net worth 
gen networth_seqq 		= seqq / atq 					// net worth (NSS definition)
gen tangnetworth		= (atq - ltq - intanq) / atq 	// tangible net worth
gen netbookleverage 	= (dlttq + dlcq - cheq) / atq  
gen cashdiv 			= dvq / l1.atq					// cash dividend payment
gen currentratio 		= actq/lctq
gen sga 				= xsgaq/l1.atq 					// sales, general, and administrative expenses
gen workingcap 			= wcapq / l1.atq 				// working capital 
gen mktlev 				= (dlttq + dlcq) / (dlttq + dlcq + mcap) // market leverage 
gen altmanz 			= 3.3*(oibdpq/atq) + saleq/atq + 1.4*req/atq ///
							+ 1.2*((actq-lctq)/atq) + 0.6*mcap/ltq // altman z score
gen totdebt 			= (dlcq + dlttq) / atq
gen ltdebt 				= (dlttq) / atq			

* bookleverage
gen booklev 			= (dlttq + dlcq) / atq 			// book leverage 
gen booklev_lt 			= dlttq / l1.atq
replace booklev = . if booklev > 1
replace booklev_lt = . if booklev_lt >1

* credit line variables
gen cashratio			= cheq / (iq_undrawn_credit + cheq)
gen undrawncredit_na 	= iq_undrawn_credit / l1.net_asset 
gen undrawnrevolver_na  = iq_undrawn_rc / l1.net_asset 
gen drawnrevolver_na    = iq_rc / l1.net_asset

* growth variables (normalized by assets)
gen lt_debt_growth  = (dlttq - l1.dlttq) / l1.atq 	// long term debt growth
gen tot_debt_growth = (dlttq + dlcq - l1.dlttq - l1.dlcq) / l1.atq 	// total book debt growth 
gen tot_debt_growth_aa = (dlttq + dlcq - l1.dlttq - l1.dlcq) / avg_asset
gen debt_minus_cash_growth = (debt_minus_cash - l1.debt_minus_cash) / l1.atq 

* update v3_jfi: remove +1 in log (so zeros are now set to missing)
gen logtotdebt   	= log(dlttq + dlcq)
gen logppe 			= log(ppentq)
gen logppe_perp 	= log(ppentq0)
gen logltdebt 		= log(dlttq)
gen logstdebt 		= log(dlcq)

gen logequitypay    = log(1+prstkcq + dvq) // in this version, if anyone is missing, then logequitypay is missing
replace logequitypay = log(1+prstkcq) if missing(logequitypay)  // this version replaces missing with either one if available
replace logequitypay = log(1+dvq) if missing(logequitypay)

gen logequitypay_1     = log(1+netequity + dvq) // in this version, if anyone is missing, then logequitypay is missing
replace logequitypay_1 = log(1+netequity) if missing(logequitypay_1)  // this version replaces missing with either one if available
replace logequitypay_1 = log(1+dvq) if missing(logequitypay_1)

gen logdivpay = log(1+dvq)
gen logneteqpurchase = log(1+netequity)

gen logcash 		= log(cheq)
gen logrd	 		= log(xrdq_adj)
gen logsale 		= log(saleq)
gen logsga 			= log(xsgaq)
gen logopcost 		= log(saleq - oibdpq)		// operating cost
gen logdrawnrevolver  = log(1+iq_rc)
gen logundrawnrevolver = log(1+iq_undrawn_rc)
gen logundrawncredit   = log(1+iq_undrawn_credit)

* growth variables (normlized by sd)
gen debitda = oibdpq - l4.oibdpq 
gegen oibdpq_sd  	= sd(debitda), by(gvkey)
gen ebitda_growth  	=  (oibdpq - l4.oibdpq)/oibdpq_sd 
drop oibdpq_sd debitda

gen aux 			= oancfq + xintq
gen daux 			= aux - l4.aux 
gegen ncocf_sd 		= sd(daux), by(gvkey)
gen ncocf_growth  	= (aux - l4.aux)/ncocf_sd
drop ncocf_sd aux daux

gen dsale = saleq - l4.saleq
gegen sale_sd 		= sd(dsale), by(gvkey)
gen sales_growth 	= (saleq - l4.saleq) / sale_sd 
drop sale_sd dsale 

gen dsga = xsgaq - l4.xsgaq 
gegen sga_sd 		= sd(dsga), by(gvkey)
gen sga_growth 	= (xsgaq - l4.xsgaq) / sga_sd 
drop sga_sd dsga

* annualized variables
gen ann_ebitda = oibdpq + l1.oibdpq + l2.oibdpq + l3.oibdpq
gen ann_sales = saleq + l1.saleq + l2.saleq + l3.saleq 

* r&d growth variable using stephen terry's method
gen rd_growth 		= (xrdq_adj - l1.xrdq_adj) / l1.atq 
gen rd_growth_t	 	= 2*(xrdq_adj - l1.xrdq_adj)/ (abs(xrdq_adj) + abs(l1.xrdq_adj))
gen capx_growth_t	= 2*(capxq - l1.capxq)/ (abs(capxq) + abs(l1.capxq))

* additional variables from chava and roberts (2008)
gen macroq 	 = (dlttq + dlcq + mcap - invtq) / l1.ppentq 
gen accruals = (ibcq - oancfq) / l1.atq

* generate option compensation 
gen optioncomp 	= xoptqp / l1.atq
gen mibatq 		= mibtq / l1.atq

* market to book ratio
gen book_equity = atq - ltq + txdcq 
gen mkt_to_book = (mcap - book_equity + atq) / atq
drop book_equity

* compute annualized changes
gen f4capx_spend_aa = (f4.capxq-capxq) / avg_asset
gen f4tot_debt_growth_aa = (f4.debt-debt) / avg_asset
gen f4acquisitions_aa= (f4.acq-acq) / avg_asset
gen f4cashhold_na = (f4.cheq-cheq) / net_asset
gen f4cashhold = (f4.cheq-cheq) / atq
gen f4ncocf_aa = (f4.oancfq + f4.xintq - oancfq - xintq) / avg_asset

* winsorize variables
loc varlist net_debt_issuance* net_equity_issuance capx_spend capx_spend_ppe rd_spend ///
	opebitda ncocf mcap tobinq cashhold booklev ppe ///
	invent receiv depre margin size acquisitions atq intpnq acq ///
	lt_debt_growth tot_debt_growth sales_growth ebitda_growth* ///
	netincome intexpense networth tangnetworth debt_minus_cash_growth netbookleverage ///
	saleatq booklev_lt altmanz cashdiv  logtotdebt logppe ///
	logequitypay currentratio logltdebt logcash equitypay ///
	rd_growth_t capx_growth_t sga macroq accruals ncocf_growth ///
	logstdebt workingcap rd_growth logrd logsale logsga mktlev sga_growth ///
	optioncomp mibatq totdebt ltdebt ///
	optioncomp_yr capx_yr opebitda_yr saleat_yr size_yr mibat_yr ///
	oplease_sp_yr oplease_perp_yr rouant_yr employment_yr ///
	ann_sales ann_ebitda ///
	capx_spend_perp ppe_perp logppe_perp ///
	emp_growth capx_spend_aa acquisitions_aa tot_debt_growth_aa opebitda_aa intexpense_aa ncocf_aa ///
	logopcost networth_seqq mkt_to_book ///
	cashratio cashhold_na undrawncredit_na undrawnrevolver_na drawnrevolver_na logdrawnrevolver ///
	f4capx_spend_aa f4tot_debt_growth_aa f4acquisitions_aa f4cashhold_na f4ncocf_aa f4cashhold ///
	logequitypay_1  logdivpay logneteqpurchase logundrawnrevolver logundrawncredit

foreach var in `varlist' {
	winsor2 `var', cuts(1 99) replace trim
}

* save results 
keep gvkey cusip datadate fyearq fqtr datefq daterq datecq sich fic ///
	net_debt_issuance* net_equity_issuance capx_spend capx_spend_ppe rd_spend ///
	opebitda ncocf mcap tobinq cashhold booklev ppe ///
	invent receiv depre margin size acquisitions atq intpnq acq ff_ind_12 sic2 ///
	lt_debt_growth tot_debt_growth sales_growth ebitda_growth* ///
	netincome intexpense networth tangnetworth debt_minus_cash_growth netbookleverage ///
	saleatq booklev_lt altmanz cashdiv  logtotdebt logppe ///
	logequitypay currentratio logltdebt logcash equitypay ///
	rd_growth_t capx_growth_t sga macroq accruals ncocf_growth ///
	logstdebt workingcap rd_growth logrd logsale logsga mktlev sga_growth ///
	optioncomp mibatq  totdebt ltdebt ///
	optioncomp_yr capx_yr opebitda_yr saleat_yr size_yr mibat_yr /// 
	oplease_sp_yr oplease_perp_yr rouant_yr employment_yr ///
	ann_sales ann_ebitda ///
	capx_spend_perp ppe_perp logppe_perp ///
	emp_growth capx_spend_aa acquisitions_aa tot_debt_growth_aa opebitda_aa intexpense_aa ncocf_aa ///
	logopcost networth_seqq mkt_to_book ///
	cashratio cashhold_na undrawncredit_na undrawnrevolver_na drawnrevolver_na logdrawnrevolver  ///
	f4capx_spend_aa f4tot_debt_growth_aa f4acquisitions_aa f4cashhold_na f4ncocf_aa  f4cashhold ///
	logequitypay_1  logdivpay logneteqpurchase logundrawnrevolver logundrawncredit
	
save "$datdir/compustat_combined_variables_quarterly_aws_3_jfi.dta", replace
