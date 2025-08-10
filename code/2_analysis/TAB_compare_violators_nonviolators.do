** Compares firm characteristics of covenant violators and non-violators using quarterly data.

clear 
global datdir "/path/to/data"
global outdir "/path/to/output"

**** load quarterly dataset 
use "$datdir/my_combined_variables_quarterly_aws_jfi_check", clear 

**** additional variables
xtset gvkey datefq
	
* indicator for a violation in the next quarter
gen fviolc_1_to_4 = (f.viol_confirmed_org==1 | f2.viol_confirmed_org==1 | f3.viol_confirmed_org==1 | f4.viol_confirmed_org==1) ///
	if !missing(f.viol_confirmed_org) | !missing(f2.viol_confirmed_org) | !missing(f3.viol_confirmed_org) | !missing(f4.viol_confirmed_org)	

gen no_past_viol = (viol_confirmed_org!=1) & (l1.viol_confirmed_org!=1) & (l2.viol_confirmed_org!=1) & (l3.viol_confirmed_org!=1) & (l4.viol_confirmed_org!=1)
gen acquisitions_aa_ann = acquisitions_aa * 4

loc varlist acquisitions_aa_ann opebitda_aa booklev intexpense_aa networth_seqq
foreach var in `varlist' {
	gen `var'_pct = `var' * 100
}

**** keep sample those where concerns are mentioned 
keep if sample_flag_any==1
keep if query_covfut_any==1
// keep if no_past_viol==1

****** compute summary statistics 

** what types of firms are these?
matrix outmat = J(11, 4, .)	 
loc varlist ///
	size logppe rating_unrated rating_ig altmanz ///
	opebitda_aa_pct booklev_pct intexpense_aa_pct networth_seqq_pct currentratio mkt_to_book 

loc cnt = 1
foreach var in `varlist' {
	
	preserve 
	
		keep gvkey datefq `var' fviolc_1_to_4
		
		drop if missing(`var')
		
		* stat for sample with subsequent violation
		qui sum `var' if fviolc_1_to_4 == 1, d
		matrix outmat[`cnt', 1] = r(mean)
// 		matrix outmat[`cnt', 2] = r(sd) / sqrt(r(N))
		
		* stat for sample with no subsequent violation
		qui sum `var' if fviolc_1_to_4 == 0, d
		matrix outmat[`cnt', 2] = r(mean)
// 		matrix outmat[`cnt', 4] = r(sd) / sqrt(r(N))
		
		* test for difference in means 
		ttest `var', by(fviolc_1_to_4)
		matrix outmat[`cnt', 3] = outmat[`cnt', 1] - outmat[`cnt', 2]
		matrix outmat[`cnt', 4] = r(se)
		
	restore 
	
	loc ++cnt

}

mat coln outmat = "Average"  "Average" "Difference" "Std. Err."
mat rown outmat = "log(Asset)" "log(PPE)" "No rating" "Investment-grade rating" "Altman z-score" "Operating earnings (\%)" ///
	"Leverage (\%)" "Interest expense (\%)" "Net worth (\%)" "Current ratio" "Market-to-book" 

esttab matrix(outmat, fmt(2 2 2 2 2 2)), replace nomtitle label	///
	mgroups("Violators" "NonViolatiors" "Difference", pattern(1 1 1 0))

esttab matrix(outmat, fmt(2 2 2 2 2 2)) using "$outdir/compare_violators_nonviolators.tex", replace nomtitle label	///
	mgroups("Violators" "NonViolatiors" "Difference", pattern(1 1 1 0)) booktabs

** replace incorrect formatting
filefilter "$outdir/compare_violators_nonviolators.tex" "$outdir/compare_violators_nonviolators_1.tex", ///
	from( ///
	"                    &   Violators&            &            &            \BS\BS" ///
	) to( ///
	"                     &\BSmulticolumn{1}{c}{Violation}& \BSmulticolumn{1}{c}{No Violation} &  \BSmulticolumn{2}{c}{Difference} \BS\BS \n  \BScmidrule(lr){2-2} \BScmidrule(lr){3-3} \BScmidrule(lr){4-5}  " ///
	) ///
	replace

//                     &\multicolumn{2}{c}{Violators}&            &            &            &            &            \\
