// Produces summary statistics for key financial and outcome variables.
// Uses combined quarterly data to compute forward-looking changes and controls.
// Produce summary statistics table

clear 
global datdir "/path/to/data"
global outdir "/path/to/output"

****** load quarterly dataset
use "$datdir/my_combined_variables_quarterly_aws_jfi_check", clear 

**** additional variables
xtset gvkey datefq

* outcome variables
gen f4size = f4.size - size 
gen f4logppe = f4.logppe - logppe 
gen f4logtotdebt = f4.logtotdebt - logtotdebt 
gen f4logequitypay = f4.logequitypay - logequitypay

gen f4logsale = f4.logsale - logsale
gen f4logopcost = f4.logopcost - logopcost
gen f4logdrawnrevolver = f4.logdrawnrevolver - logdrawnrevolver

gen f4rating_default= (rating_default==1) | (f1.rating_default==1) | (f2.rating_default==1) | (f3.rating_default==1) | (f4.rating_default==1) ///
	if !missing(rating_numeric) | !missing(f1.rating_numeric) | !missing(f2.rating_numeric) | !missing(f3.rating_numeric)  | !missing(f4.rating_numeric)

gen f4bankruptcy_filing= (bankruptcy_filing==1) | (f1.bankruptcy_filing==1) | (f2.bankruptcy_filing==1) | (f3.bankruptcy_filing==1) | (f4.bankruptcy_filing==1) ///
	if !missing(bankruptcy_filing) | !missing(f1.bankruptcy_filing) | !missing(f2.bankruptcy_filing) | !missing(f3.bankruptcy_filing) | !missing(f4.bankruptcy_filing)	

gen f4rating_downgrade= (rating_numeric>l1.rating_numeric) | (f1.rating_numeric>l1.rating_numeric) | (f2.rating_numeric>l1.rating_numeric) | (f3.rating_numeric>l1.rating_numeric) | (f4.rating_numeric>l1.rating_numeric) ///
	if !missing(rating_numeric) | !missing(f1.rating_numeric) | !missing(f2.rating_numeric) | !missing(f3.rating_numeric)  | !missing(f4.rating_numeric)

gen f4cashratio = f4.cashratio - cashratio	
	
* these variables are computed in gen_compustat_combined
gen f4capx_spend_aa_ann = f4capx_spend_aa*4
gen f4acquisitions_aa_ann= f4acquisitions_aa*4
gen f4ncocf_aa_ann = f4ncocf_aa*4
gen capx_spend_aa_ann = capx_spend_aa*4 
gen acquisitions_aa_ann = acquisitions_aa*4
gen ncocf_aa_ann = ncocf_aa*4 

********** 
* keep relevant sample 
keep if sample_flag_any==1

****** compute summary statistics 

matrix outmat = J(31, 6, .)	 
loc varlist ///
	viol_confirmed_org query_covfut_any size logppe capx_spend_aa_ann acquisitions_aa_ann emp_growth ///
	logtotdebt tot_debt_growth_aa logequitypay cashhold logundrawnrevolver logdrawnrevolver ///
	ncocf_aa_ann logsale logopcost rating_downgrade bankruptcy_filing r_avg_termloan logloan_amount_termloan ///
	r_avg_revolver logloan_amount_revolver ///
	opebitda_aa booklev intexpense_aa networth_seqq currentratio mkt_to_book ///
	altmanz rating_unrated rating_ig
	
loc cnt = 1
foreach var in `varlist' {
	
	preserve 
	
		keep gvkey datefq `var'
		
		drop if missing(`var')
		
		* stat for full sample
		qui sum `var', d
		matrix outmat[`cnt',1] = r(N)
		matrix outmat[`cnt',2] = r(mean)
		matrix outmat[`cnt',3] = r(p50)
		matrix outmat[`cnt',4] = r(sd)
		matrix outmat[`cnt',5] = r(p10)
		matrix outmat[`cnt',6] = r(p90)
		
		
	restore 
	
	loc ++cnt

}


* for employment growth, use annual variable 
preserve 
	use "$datdir/my_combined_variables_annual_aws_jfi_check", clear  
	keep if sample_flag_any==1
	
	loc var employment 
	qui sum `var', d
	matrix outmat[7,1] = r(N)
	matrix outmat[7,2] = r(mean)
	matrix outmat[7,3] = r(p50)
	matrix outmat[7,4] = r(sd)
	matrix outmat[7,5] = r(p10)
	matrix outmat[7,6] = r(p90)
		
restore 

mat coln outmat = "Count" "Average" "Median" "SD" "10th pct" "90th pct"
mat rown outmat = "Covenant Violation" "CovConcerns" "log(Asset)" "log(PPE)" "Capx/Asset" "CashAcq/Asset" "Employment" ///
	"log(Debt)" "NDI/Asset" "log(Payout)" "Cash/Asset" "log(Undrawn Revolver)" "log(Drawn Revolver)" "CashFlow/Asset" "log(Sale)" "log(OpCost)" "1(Downgrade)" "1(Default)" ///
	"Spread (TL)" "log(Loan Amount) (TL)" "Spread (CL)" "log(Loan Amount) (CL)" ///
	"Operating earnings" "Leverage" "Interest expense" "Net worth" "Current ratio" "Market-to-book" ///
	"Altman z-score" "Unrated" "Investment grade rating"

	
esttab matrix(outmat, fmt(0 2 2 2 2 2)), replace nomtitle label	
esttab matrix(outmat, fmt(0 2 2 2 2 2)) using "$outdir/summary-statistics_nov2024.tex", replace nomtitle label	booktabs
