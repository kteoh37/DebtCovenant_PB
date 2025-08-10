* Assess whether loan level characteristics affect covenant concerns 

	
clear 
global datdir "/Users/kenteoh/Dropbox/debt_covenant/data_jfi_fin"
global outdir "/Users/kenteoh/Dropbox/debt_covenant/output_jfi_fin"

* --------------------------------------------------------------------
* load data

* main data
use "$datdir/my_combined_variables_quarterly_aws_jfi_check", clear 
drop sic2 sich

* merge loan level characteristics 
merge m:1 gvkey datecq using "$datdir/dealscan_gvkey_loan_type_panel.dta", keep(1 3) nogen

* merge number of loans initiated by lenders
merge m:1 gvkey datecq using "$datdir/dealscan_gvkey_lender_nloan.dta", keep(1 3) nogen

* end of maturity dates
merge m:1 gvkey datecq using "$datdir/dealscan_borrower_tranche_maturity_date_panel", keep(1 3) nogen

* --------------------------------------------------------------------
* housekeeping 

gduplicates drop gvkey datecq, force // 240 obs 
winsor2 nlender, trim cut(0 99) replace

* --------------------------------------------------------------------
* generate variables


xtset gvkey datecq

gen loglender = log(nlender) 
gen loglender_nloan = log(lender_nloan) // lender's market share 
gen loglender_nloan_sic = log(lender_nloan_sic)
gegen inst_loan_ind = mean(inst_loan), by(sic2 datecq)
gen rd_ind = (ratio_diff < 0.05) if !missing(ratio_diff)
gen ratio_diff2 = ratio_diff^2

gen deal_amount_to_asset = deal_amount / l1.atq
winsor2 deal_amount_to_asset, trim cut(0 99) replace
drop if deal_amount_to_asset >1

gen logit_lender_mktshare = log(lender_mktshare / (100 - lender_mktshare))

* additional variables
gen pre_viol = viol_confirmed!=1 & l1.viol_confirmed!=1 & l2.viol_confirmed!=1 & l3.viol_confirmed!=1 & l4.viol_confirmed!=1
gen pre_viol_l1 = l1.viol_confirmed!=1 & l2.viol_confirmed!=1 & l3.viol_confirmed!=1 & l4.viol_confirmed!=1
gen post_viol = f1.viol_confirmed==1 | f2.viol_confirmed==1 | f3.viol_confirmed==1 | f4.viol_confirmed==1
gen capx_spend1 = capx_spend * 100
gen net_debt_issuance1 = net_debt_issuance * 100
gen query_covfut_pct = query_covfut_any* 100
gen query_cov_pct = query_cov_any * 100
gen viol_confirmed_pct = viol_confirmed_org * 100
replace rating_numeric = 99 if missing(rating_numeric)
gen booklev_pct = booklev * 100

* compute forward difference 
loc varlist logsale logsga opebitda ncocf ///
	capx_spend1 logstdebt logltdebt logtotdebt ///
	logcash logequitypay size logppe net_debt_issuance1 ///
	logppe_perp
foreach var in `varlist' {
	gen `var'_pct = `var' * 100 
	gen f4`var' = f4.`var'_pct - l1.`var'_pct
	gen `var'l1 = l1.`var'_pct
}

* high / low lender share
cap drop hi_lender 
gen hi_lender =.
replace hi_lender = l1.nlenders>1
replace hi_lender =. if missing(nlenders)
// gquantiles hi_lender=loglender, xtile nq(2) by(datecq)

* quantiles of deal amount
gquantiles large_loan=deal_amount_to_asset, xtile nq(2) by(datecq)
gquantiles tight_lend=lendertight, xtile nq(2)
gquantiles hi_share = logit_lender_mktshare, xtile nq(2) by(datecq)

* lagged variables
gen l1_loglender_nloan = l1.loglender_nloan
gen l1_loglender = l1.loglender
gen l1_inst_loan = l1.inst_loan 
gen l1_inst_loan_ind = l1.inst_loan_ind * 100
gen l1_trad_bank = l1.trad_bank_loan 
gen l1_private_loan = l1.private_loan 
gen l1_termA = l1.termA 
gen l1_inst_loan_bny = l1.inst_loan_bny 
gen l1_deal_amount_to_asset= l1.deal_amount_to_asset
gen l1_lender_mktshare = l1.lender_mktshare
gen l1_logit_lender_mktshare = l1.logit_lender_mktshare

* keep valid sample
keep if sample_flag_any==1

* --------------------------------------------------------------------
* binscatter 

qui binsreg query_covfut_pct ebitda_growth size deal_amount_to_asset, by(inst_loan) xline(0, lpattern(dot) lwidth(.5)) ///
	ytitle("") graphregion(color(white)) plotregion(fcolor(white) margin(zero)) nbins(25) ///
	legend(order(1 "No institutional lender" 2 "With institutional lender") ring(0) position(1)) ///
	xtitle("Change in earnings (sd)") name("query_inst_loan", replace) nodraw
	
qui binsreg query_covfut_pct ebitda_growth size deal_amount_to_asset, by(inst_loan_bny) xline(0, lpattern(dot) lwidth(.5)) ///
	ytitle("") graphregion(color(white)) plotregion(fcolor(white) margin(zero)) nbins(25) ///
	legend(order(1 "No Term B-D Loans" 2 "With Term B-D Loans") ring(0) position(1)) ///
	xtitle("Change in earnings (sd)") name("query_termB", replace) nodraw
	
qui binsreg query_covfut_pct ebitda_growth size deal_amount_to_asset, by(hi_lender) xline(0, lpattern(dot) lwidth(.5)) ///
	ytitle("") graphregion(color(white)) plotregion(fcolor(white) margin(zero)) nbins(25) ///
	legend(order(1 "Single Lender" 2 "Multiple Lenders") ring(0) position(1)) ///
	xtitle("Change in earnings (sd)") name("query_nlenders", replace) 

graph combine query_inst_loan query_nlenders, row(1) ///
	graphregion(color(white)) plotregion(fcolor(white) margin(zero)) name(combine_2, replace) xsize(8in) ysize(4in) ycommon altshrink 
graph export "$outdir/earnings_lender.pdf", as(pdf) replace	


* --------------------------------------------------------------------
* variable labels 

label var query_covfut_pct "CovConcerns"
label var l1_trad_bank "L.Traditional Bank Loan"
label var l1_inst_loan "L.Institutional Loan"
label var l1_private_loan "L.Private Loan"
label var l1_termA "L.Term A Loan"
label var l1_inst_loan_bny "L.Term B-D Loans"
label var l1_inst_loan_ind "L.Ind. Institutional Share"
label var l1_loglender "L.log(Participants)"
label var l1_loglender_nloan "L.log(Lead Portfolio)"
label var booklev_pct "Leverage"
label var size "log(Asset)"
label var sales_growth "Sales Growth"
label var ncocf_pct "Cash Flow"
label var tobinq "Tobin's Q"

* --------------------------------------------------------------------
* relationship between covconcerns and lender characteristics

cap drop keep_flag
gen keep_flag = !missing(l1_trad_bank) & !missing(l1_termA) & !missing(l1_loglender)

est clear 

reghdfe query_covfut_pct l1_trad_bank l1_inst_loan l1_private_loan ///
	booklev_pct size sales_growth ncocf_pct tobinq ///
	if keep_flag==1, absorb(sic2 datefq b99.rating_numeric) cluster(gvkey)
eststo m1
qui estadd loc firm "\checkmark"
qui estadd loc time "\checkmark"
qui estadd loc rating "\checkmark"

qui reghdfe query_covfut_pct l1_termA l1_inst_loan_bny ///
	booklev_pct size sales_growth ncocf_pct tobinq ///
	if keep_flag==1, absorb(sic2 datefq b99.rating_numeric) cluster(gvkey)
eststo m2	
qui estadd loc firm "\checkmark"
qui estadd loc time "\checkmark"
qui estadd loc rating "\checkmark"

qui reghdfe query_covfut_pct l1_loglender ///
	booklev_pct size sales_growth ncocf_pct tobinq ///
	if keep_flag==1, absorb(sic2 datefq b99.rating_numeric) cluster(gvkey)
eststo m3
qui estadd loc firm "\checkmark"
qui estadd loc time "\checkmark"
qui estadd loc rating "\checkmark"


esttab m1 m2 m3,  ///
	drop(_cons) ///
	order(l1_trad_bank l1_inst_loan l1_private_loan l1_termA l1_inst_loan_bny  l1_loglender) ///
	noconst b(3) se(3) nonotes ///
	mtitle("CovConcerns" "CovConcerns" "CovConcerns") ///
	label compress starlevels(* 0.10 ** 0.05 *** 0.01) ///
	stats(firm time rating r2 N, fmt(a2) ///
	labels("Industry FE" "Time FE" "Rating control" "R-squared" "No. observations"))


esttab m1 m2 m3 using "$outdir/regression_results_lender.tex", replace  ///
	drop(_cons) ///
	order(l1_trad_bank l1_inst_loan l1_private_loan l1_termA l1_inst_loan_bny  l1_loglender) ///
	noconst b(3) se(3) nonotes ///
	mtitle("CovConcerns" "CovConcerns" "CovConcerns") ///
	label compress starlevels(* 0.10 ** 0.05 *** 0.01) ///
	stats(firm time rating r2 N, fmt(a2) ///
	labels("Industry FE" "Time FE" "Rating control" "R-squared" "No. observations")) booktabs


* presentation version
esttab m1 m2 m3 using "$outdir/regression_results_lender_present.tex", replace  ///
	drop(_cons booklev_pct size sales_growth ncocf_pct tobinq l1_private_loan) ///
	order(l1_trad_bank l1_inst_loan l1_private_loan l1_termA l1_inst_loan_bny  l1_loglender) ///
	noconst b(3) se(3) nonotes booktabs ///
	mtitle("CovConcerns" "CovConcerns" "CovConcerns") ///
	label compress starlevels(* 0.10 ** 0.05 *** 0.01) ///
	stats(firm rating r2 N, fmt(a2) ///
	labels("Industry \& Time FE" "Firm controls" "R-squared" "No. observations"))

