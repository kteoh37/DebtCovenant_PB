*** predict future violations with anticipation -- variable by variable
** version: August 2024

clear 
global datdir "/path/to/data"
global outdir "/path/to/output"

**** load quarterly dataset 
use "$datdir/my_combined_variables_quarterly_aws_jfi_check", clear 

**** additional variables
xtset gvkey datefq

gen fviolc_1_to_1 = f1.viol_confirmed_org * 100
gen fviolc_1_to_4 = 100*(f.viol_confirmed_org==1 | f2.viol_confirmed_org==1 ///
	| f3.viol_confirmed_org==1 | f4.viol_confirmed_org==1) ///
	if !missing(f.viol_confirmed_org) | !missing(f2.viol_confirmed_org) ///
	| !missing(f3.viol_confirmed_org) | !missing(f4.viol_confirmed_org)
	
* non linear controls
gen opebitda_aa_pct = opebitda_aa * 100
gen intexpense_aa_pct = intexpense_aa * 100

gen no_past_viol = viol_confirmed_org!=1 & l1.viol_confirmed_org!=1 ///
	& l2.viol_confirmed_org!=1 & l3.viol_confirmed_org!=1

***** label variables
label var query_covfut_any "CovConcerns (t)"
label var opebitda_aa_pct "Earnings (t)"
label var ratio_diff "Covenant Slack (t)"
label var viol_confirmed_org "Violation (t)"
label var booklev "Leverage (t)"
label var intexpense_aa_pct "Interest Expense (t)"
label var networth_seqq "Net Worth (t)"
label var currentratio "Current Ratio (t)"
label var mkt_to_book "Market-to-Book (t)"


***** keep sample
keep if sample_flag_any==1
	
***** regression: predicting future violations

cap drop valid_flag
gen valid_flag = 1 if ///
	!missing(query_covfut_any) & !missing(opebitda_aa_pct) ///
	& !missing(booklev) & !missing(intexpense_aa_pct) & !missing(networth_seqq) & !missing(currentratio) & !missing(mkt_to_book)  ///
	& !missing(hol4_booklev) & !missing(hol4_opebitda_aa) ///
	& !missing(hol4_intexpense_aa) & !missing(hol4_networth_seqq) & !missing(hol4_currentratio) & !missing(hol4_mkt_to_book) ///
	& no_past_viol==1

est clear

** 1. baseline specification
qui reghdfe fviolc_1_to_4 ///
	query_covfut_any ///
	if valid_flag==1, absorb(gvkey datefq) cluster(gvkey)
	
loc coef = r(table)[1,1]
qui sum fviolc_1_to_4 if valid_flag==1
loc violavg = `r(mean)'
estadd scalar violavg `violavg'
loc relchg = (`coef' / `violavg' ) * 100
estadd scalar relchg `relchg'
	
est store m1
estadd local firm "\checkmark"
estadd local ho ""
	
** 2. control for earnings 
qui reghdfe fviolc_1_to_4 ///
	query_covfut_any ///
	opebitda_aa_pct ///
	if valid_flag==1, absorb(gvkey datefq) cluster(gvkey)	
	
loc coef = r(table)[1,1]
qui sum fviolc_1_to_4 if valid_flag==1
loc violavg = `r(mean)'
estadd scalar violavg `violavg'
loc relchg = (`coef' / `violavg' ) * 100
estadd scalar relchg `relchg'

est store m2
estadd local firm "\checkmark"
estadd local ho ""


** 3. control for additional covenant variables
qui reghdfe fviolc_1_to_4 ///
	query_covfut_any ///
	opebitda_aa_pct booklev intexpense_aa_pct networth_seqq currentratio mkt_to_book ///
	if valid_flag==1, absorb(gvkey datefq) cluster(gvkey)	
	
loc coef = r(table)[1,1]
qui sum fviolc_1_to_4 if valid_flag==1
loc violavg = `r(mean)'
estadd scalar violavg `violavg'
loc relchg = (`coef' / `violavg' ) * 100
estadd scalar relchg `relchg'

est store m3
estadd local firm "\checkmark"
estadd local ho ""


** 4. control for higher order terms
qui reghdfe fviolc_1_to_4 ///
	query_covfut_any ///
	opebitda_aa_pct booklev intexpense_aa_pct networth_seqq currentratio mkt_to_book ///
	ho2_* ho3_* hol4_*  ///
	if valid_flag==1, absorb(gvkey datefq) cluster(gvkey)	
	
loc coef = r(table)[1,1]
qui sum fviolc_1_to_4 if valid_flag==1
loc violavg = `r(mean)'
estadd scalar violavg `violavg'
loc relchg = (`coef' / `violavg' ) * 100
estadd scalar relchg `relchg'

est store m4
estadd local firm "\checkmark"
estadd local ho "\checkmark"



** 5. control for covenant slack 
qui reghdfe fviolc_1_to_4 ///
	query_covfut_any ///
	ratio_diff ///
	if valid_flag==1, absorb(gvkey datefq) cluster(gvkey)	

loc coef = r(table)[1,1]
qui sum fviolc_1_to_4 if valid_flag==1 & !missing(ratio_diff)
loc violavg = `r(mean)'
estadd scalar violavg `violavg'
loc relchg = (`coef' / `violavg' ) * 100
estadd scalar relchg `relchg'

est store m5
estadd local firm "\checkmark"
estadd local ho ""

esttab m1 m5 m2 m3 m4,  ///
	noconst b(2) ///
	order(query_covfut_any ratio_diff  opebitda_aa_pct  booklev intexpense_aa_pct networth_seqq currentratio mkt_to_book ) ///
	keep(query_covfut_any  ratio_diff  opebitda_aa_pct  booklev intexpense_aa_pct networth_seqq currentratio mkt_to_book ) ///
	label compress starlevels(* 0.10 ** 0.05 *** 0.01) ///	
	stats(violavg relchg ho firm r2 N, fmt(2 2 0 0 2 0) layout(@ @ @ @ @ @) ///
	labels("Avg. Violation Prob." "\% Change" "Higher Order Control" "Firm \& Quarter FE" "$\textit{R}^2$" "$\textit{N}$") ) 
 
esttab m1 m5 m2 m3 m4 using "$outdir/predict_future_viol_2.tex", replace ///
		noconst b(2) se(2) nomtitle nonotes ///
		mgroup("Covenant Violation (t+1 to t+4)", pattern(1 0 0 0 0) ///
		prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) ///
	order(query_covfut_any ratio_diff  opebitda_aa_pct  booklev intexpense_aa_pct networth_seqq currentratio mkt_to_book ) ///
	keep(query_covfut_any ratio_diff  opebitda_aa_pct  booklev intexpense_aa_pct networth_seqq currentratio mkt_to_book) ///
	label compress starlevels(* 0.10 ** 0.05 *** 0.01) ///	
	stats(violavg relchg ho firm r2 N, fmt(2 2 0 0 2 0) layout(@ @ @ @ @ @) ///
	labels("Avg. Violation Prob." "\% Change" "Higher Order Control" "Firm \& Quarter FE" "$\textit{R}^2$" "$\textit{N}$") )   booktabs

	