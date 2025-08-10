// Assemble annual Compustat financials and interpolate missing balance sheet items.
// Produces firm-year variables used in covenant and performance analyses.

clear 
global maindir "/path/to/project"
global rawdir "$maindir/rawdata_jfi_fin"
global datdir "$maindir/data_jfi_fin"

// -------------------------------------------------------
// import data here 
use "$rawdir/wrds/compustat_funda_00-20", clear 
drop index
// drop if missing(cusip)
gen tmp = dofc(datadate)
format %td tmp 
drop datadate 
rename tmp datadate

// -------------------------------------------------------
// housekeeping

// extra selection 
replace sale = . if sale < 0 // measurement error 
replace emp = . if emp < 0 

// interpolate stock variables 
loc varlist dltt dlc at ppent ppegt 
foreach var in `varlist' {
	bys gvkey (fyear): ipolate `var' fyear, gen(tmp)
	drop `var'
	rename tmp `var'
}

// -------------------------------------------------------
// construct variables 
destring gvkey, replace
xtset gvkey fyear

gen avg_asset = (at + l1.at) /2 	// average asset

gen debt = dltt + dlc 							// debt growth
gen debt_issuance   = (dltis - dltr) / l1.at 		// net debt issuance
gen lt_debt_growth  = (dltt - l1.dltt) / l1.at 	// long term debt growth
gen tot_debt_growth = (debt - l1.debt) / l1.at 	// total book debt growth 
gen logdebt 		= log(debt)

gen capx_spend 		= capx / l1.at 				// capital expendiure
gen rd_spend 		= xrd / l1.at 				// r&d spending
gen opebitda 		= ebitda / l1.at 				// operating earnings ebitda
gen opebitda_aa 	= ebitda / avg_asset 
gen ncocf 			= (oancf + xint) / l1.at 		// operating earnings ebitda 
gen tobinq			= (dltt + dlc + prc*shrout/1000) / at 	// tobin's q 
gen tobinq_kz 		= (at + prcc_f*csho - ceq - txdb) / at   // tobin's q (KZ definition)
gen cashhold	 	= che / at 					// cash holding
gen ppe				= ppent / at 				// ppe
gen invent 			= invt / at 				// inventory
gen receiv			= rect / at 				// receivable 
gen depre			= dp / l1.at 					// depreciation
gen margin 			= ebitda / sale				// margin 
gen size 			= log(at)					// size
gen equity_issuance = (sstk - prstkc) / l1.at 	// sale of common equity - purchase of common equity 
gen mcap 			= prc* shrout/1000
gen sale_growth     = log(sale) - log(l1.sale) 
gen cashhold_growth =  cashhold - l1.cashhold
gen intexpense_aa 	= xint / avg_asset
gen intexpense 		= xint / l1.at
gen networth_seqq 	= seq / at 
gen networth 		= (at - lt) / at
gen currentratio	= act / lct
gen emp_growth 		= (emp - l1.emp) / emp
gen logsale 		= log(sale)
gen employment 		= emp 
gen logemployment   = log(employment)
gen emp_ppe 		= (emp - l1.emp) / l1.ppent
gen emp_asset       = (emp - l1.emp) / l1.at
gen emp_growth_sym  = 2 * (emp - l1.emp) / (emp + l1.emp)


gen booklev 		= debt / at 				// book leverage 
gen lt_booklev 		= dltt / at 
replace booklev =. if booklev >1
replace lt_booklev=. if lt_booklev>1

gen book_equity = at - lt + txdb 
gen mkt_to_book = (mcap - book_equity + at) / at
drop book_equity

* winsorize variables
loc varlist debt_issuance lt_debt_growth tot_debt_growth logdebt ///
	capx_spend rd_spend opebitda opebitda_aa ncocf tobinq tobinq_kz ///
	cashhold ppe invent receiv depre margin size equity_issuance ///
	mcap sale_growth cashhold_growth intexpense_aa intexpense ///
	networth_seqq networth currentratio booklev lt_booklev ///
	mkt_to_book emp_growth at logsale employment ///
	logemployment emp_ppe emp_asset emp_growth_sym

foreach var in `varlist' {
	winsor2 `var', cuts(1 99) replace trim
}

// save results 
keep gvkey cusip fyear sich fic debt_issuance lt_debt_growth tot_debt_growth logdebt ///
	capx_spend rd_spend opebitda opebitda_aa ncocf tobinq tobinq_kz ///
	cashhold ppe invent receiv depre margin size equity_issuance ///
	mcap sale_growth cashhold_growth intexpense_aa intexpense ///
	networth_seqq networth currentratio booklev lt_booklev ///
	mkt_to_book at logsale emp_growth employment ///
	logemployment emp_ppe emp_asset emp_growth_sym

save "$datdir/compustat_combined_variables_annual_2024_09.dta", replace

