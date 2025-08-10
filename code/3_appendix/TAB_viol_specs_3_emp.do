// Evaluates employment responses to covenant violations using annual data.
// Runs regressions on employment growth and related measures.

clear 
global datdir "/path/to/data"
global outdir "/path/to/output"

** load annual dataset
use "$datdir/my_combined_variables_annual_aws_jfi_check", clear  
xtset gvkey fyear 
gen viol_confirmed_org_l1 = l1.viol_confirmed_org
destring sic2, replace

gen has_controls = !missing(viol_confirmed_org_l1) & !missing(opebitda_aa) ///
& !missing(booklev) & !missing(intexpense_aa) & !missing(networth_seqq) ///
& !missing(currentratio) & !missing(mkt_to_book) ///
& !missing(hol1_booklev) & !missing(hol1_intexpense_aa) & !missing(hol1_networth_seqq) ///
& !missing(hol1_currentratio) & !missing(hol1_mkt_to_book)

keep if sample_flag_any==1


** convert to percentage
loc varlist  emp_ppe emp_asset
foreach var in `varlist' {
	gen ax = `var' * 100
	drop `var'
	rename ax `var'
}

**********
* label variables

label var viol_confirmed_org "Covenant Violation"


**** run regression 
est clear 

loc depvarlist emp_growth emp_growth_sym logemployment emp_ppe emp_asset
loc i = 1

foreach depvar in `depvarlist' {

	*-----------------------------------------------------------------
	* A. Baseline (Full sample)
	qui reghdfe `depvar' viol_confirmed_org viol_confirmed_org_l1 ///
		opebitda_aa booklev intexpense_aa networth_seqq currentratio mkt_to_book ///
		ho2_* ho3_* hol1_* ///
		if !missing(query_covfut_any_l1_l1), absorb(sic2 fyear) cluster(gvkey)
	
	est store a`i'
	qui estadd loc firm "\checkmark"
	qui estadd loc controls "\checkmark"

	*-----------------------------------------------------------------
	* B. Use anticipation as control 

	qui reghdfe `depvar' viol_confirmed_org viol_confirmed_org_l1 query_covfut_any_l1_l1 ///
		opebitda_aa booklev intexpense_aa networth_seqq currentratio mkt_to_book ///
		ho2_* ho3_* hol1_*  ///
		if !missing(query_covfut_any_l1_l1), absorb(sic2 fyear) cluster(gvkey)

	est store b`i'
	qui estadd loc firm "\checkmark"
	qui estadd loc controls "\checkmark"
		
	*-----------------------------------------------------------------
	* C. Use intensive anticipation as control	

	qui reghdfe `depvar' viol_confirmed_org viol_confirmed_org_l1 ///
		opebitda_aa booklev intexpense_aa networth_seqq currentratio mkt_to_book ///
		ho2_* ho3_* hol1_*  ///
		if query_covfut_wc_any_hi_l1_l1==0 & !missing(query_covfut_wc_any_hi_l1_l1), absorb(sic2 fyear) cluster(gvkey)

	est store c`i'
	qui estadd loc firm "\checkmark"
	qui estadd loc controls "\checkmark"
			
	*-----------------------------------------------------------------
	* D. Drop sample where anticipation occurs in t-1 (annual)
	qui reghdfe `depvar' viol_confirmed_org  viol_confirmed_org_l1 ///
			opebitda_aa booklev intexpense_aa networth_seqq currentratio mkt_to_book ///
			ho2_* ho3_* hol1_*  ///
			if query_covfut_any_l1_l1==0 & !missing(query_covfut_any_l1_l1), absorb(sic2 fyear) cluster(gvkey)	

	est store d`i'
	qui estadd loc firm "\checkmark"	
	
	loc i = `i'+1
}

**** save results
* Panel A: Full sample
esttab a* using "$outdir/regression_violation_1_emp_may2025.tex", ///
       keep(viol_confirmed_org) mtitles("Emp Growth" "Sym Emp Growth" "Log(Employment)" "Emp/PPE" "Emp/Asset") ///
       se(3) b(3) label compress starlevels(* 0.10 ** 0.05 *** 0.01) ///
       stats(N, fmt(0) layout(@) ///
             labels("Observations")) ///
	   replace fragment posthead("\addlinespace \midrule  \multicolumn{3}{l}{\textit{Panel A: Full Sample}} & & & \\ ")

* Panel B: Anticipation as control
esttab b* using "$outdir/regression_violation_1_emp_may2025.tex", ///
       keep(viol_confirmed_org) nomtitle nonum ///
       se(3) b(3) label compress starlevels(* 0.10 ** 0.05 *** 0.01) ///
       stats(N, fmt(0) layout(@) ///
             labels("Observations")) ///
       append fragment posthead("\addlinespace \midrule  \multicolumn{3}{l}{\textit{Panel B: Control for anticipation}} & & & \\ ")

* Panel C: Mild bounding
esttab c* using "$outdir/regression_violation_1_emp_may2025.tex", ///
       keep(viol_confirmed_org) nomtitle nonum ///
       se(3) b(3) label compress starlevels(* 0.10 ** 0.05 *** 0.01) ///
       stats(N, fmt(0) layout(@) ///
             labels("Observations")) ///
       append fragment posthead("\addlinespace \midrule  \multicolumn{3}{l}{\textit{Panel C: Exclude intensive anticipation}} & & & \\ ")

* Panel D: Strict bounding
esttab d* using "$outdir/regression_violation_1_emp_may2025.tex", ///
       keep(viol_confirmed_org) nomtitle nonum ///
       se(3) b(3) label compress starlevels(* 0.10 ** 0.05 *** 0.01) ///
       stats(N, fmt(0) layout(@) ///
             labels("Observations")) ///
       append fragment posthead("\addlinespace \midrule  \multicolumn{3}{l}{\textit{Panel D: Exclude any anticipation}} & & & \\ ")  postfoot("\addlinespace \midrule \addlinespace  \addlinespace")





