// Tabulate violation specifications using Dealscan variables
clear 
global datdir "/path/to/data"
global outdir "/path/to/output"

**** load quarterly dataset 
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
gen f4logundrawnrevolver = f4.logundrawnrevolver - logundrawnrevolver
gen f4logundrawncredit = f4.logundrawncredit - logundrawncredit


gen f4rating_default= (rating_default==1) | (f1.rating_default==1) | (f2.rating_default==1) | (f3.rating_default==1) | (f4.rating_default==1) ///
	if !missing(rating_numeric) | !missing(f1.rating_numeric) | !missing(f2.rating_numeric) | !missing(f3.rating_numeric)  | !missing(f4.rating_numeric)

gen f4bankruptcy_filing= (bankruptcy_filing==1) | (f1.bankruptcy_filing==1) | (f2.bankruptcy_filing==1) | (f3.bankruptcy_filing==1) | (f4.bankruptcy_filing==1) ///
	if !missing(bankruptcy_filing) | !missing(f1.bankruptcy_filing) | !missing(f2.bankruptcy_filing) | !missing(f3.bankruptcy_filing) | !missing(f4.bankruptcy_filing)	

gen f4rating_downgrade= (rating_numeric>l1.rating_numeric) | (f1.rating_numeric>l1.rating_numeric) | (f2.rating_numeric>l1.rating_numeric) | (f3.rating_numeric>l1.rating_numeric) | (f4.rating_numeric>l1.rating_numeric) ///
	if !missing(rating_numeric) | !missing(f1.rating_numeric) | !missing(f2.rating_numeric) | !missing(f3.rating_numeric)  | !missing(f4.rating_numeric)

gen f4cashratio = f4.cashratio - cashratio	
gen f4logcash = f4.logcash - logcash	
	
* these variables are computed in gen_compustat_combined
gen f4capx_spend_aa_ann = f4capx_spend_aa* 4
gen f4acquisitions_aa_ann= f4acquisitions_aa*4
gen f4ncocf_aa_ann = f4ncocf_aa*4
gen capx_spend_aa_ann = capx_spend_aa*4
gen acquisitions_aa_ann = acquisitions_aa*4

* lagged variables
gen viol_dsc_l4 = l4.viol_dsc
gen capx_spend_aa_ann_l1 = l1.capx_spend_aa*4 
gen acquisitions_aa_ann_l1 = l1.acquisitions_aa*4 

* indicator for observation with all controls
gen has_controls = !missing(viol_dsc_l4) & !missing(opebitda_aa) ///
	& !missing(booklev) & !missing(intexpense_aa) & !missing(networth_seqq) ///
	& !missing(currentratio) & !missing(mkt_to_book) ///
	& !missing(hol4_booklev) & !missing(hol4_intexpense_aa) & !missing(hol4_networth_seqq) ///
	& !missing(hol4_currentratio) & !missing(hol4_mkt_to_book)
	

********** 
* keep relevant sample 
keep if sample_flag_any==1

**********
* label variables

label var viol_dsc "Violation (Dealscan)"

**********
* full sample & split sample

**--------------------------------------------------------------------
* 1. investment variables
* unconditional
loc depvarlist f4size f4logppe capx_spend_aa_ann acquisitions_aa_ann

est clear 
loc i = 1
foreach depvar in `depvarlist' {
	
	*-----------------------------------------------------------------
	* A. Baseline (Full sample)
	
	if (`i'!=3) & (`i'!=4) {
		qui reghdfe `depvar' viol_dsc viol_dsc_l4 ///
		opebitda_aa booklev intexpense_aa networth_seqq currentratio mkt_to_book ///
		ho2_* ho3_* hol4_*  ///
		if !missing(query_covfut_any_l1_l4), absorb(sic2 datefq) cluster(gvkey)
	}
	else {
		qui reghdfe `depvar' viol_dsc viol_dsc_l4 `depvar'_l1 ///
		opebitda_aa booklev intexpense_aa networth_seqq currentratio mkt_to_book ///
		ho2_* ho3_* hol4_*  ///
		if !missing(query_covfut_any_l1_l4), absorb(sic2 datefq) cluster(gvkey)
	}
	
    
	scalar num_clusters = e(N_clust)
	
	qui sum viol_dsc if ///
		!missing(query_covfut_any_l1_l4) & viol_dsc==1 ///
		& !missing(`depvar') & has_controls==1
	scalar nviol = `r(N)'
	
	est store a1_`i'
	qui estadd loc firm "\checkmark"
	qui estadd loc controls "\checkmark"
	estadd scalar num_clusters = num_clusters
	estadd scalar nviol = nviol
	
// 	*-----------------------------------------------------------------
// 	* B. Use anticipation as control 
//	
// 	if (`i'!=3) & (`i'!=4) {
// 		qui reghdfe `depvar' viol_dsc viol_dsc_l4 query_covfut_any_l1_l4 ///
// 		opebitda_aa booklev intexpense_aa networth_seqq currentratio mkt_to_book ///
// 		ho2_* ho3_* hol4_*  ///
// 		if !missing(query_covfut_any_l1_l4), absorb(sic2 datefq) cluster(gvkey)
// 	}
// 	else {
// 		qui reghdfe `depvar' viol_dsc viol_dsc_l4 `depvar'_l1 query_covfut_any_l1_l4 ///
// 		opebitda_aa booklev intexpense_aa networth_seqq currentratio mkt_to_book ///
// 		ho2_* ho3_* hol4_*  ///
// 		if !missing(query_covfut_any_l1_l4), absorb(sic2 datefq) cluster(gvkey)
// 	}
//	
//
// 	scalar num_clusters = e(N_clust)
//	
// 	qui sum viol_dsc if ///
// 		!missing(query_covfut_any_l1_l4) & viol_dsc==1 ///
// 		& !missing(`depvar') & has_controls==1
// 	scalar nviol = `r(N)'
//	
// 	est store b1_`i'
// 	qui estadd loc firm "\checkmark"
// 	qui estadd loc controls "\checkmark"
// 	estadd scalar num_clusters = num_clusters
// 	estadd scalar nviol = nviol

	
// 	*-----------------------------------------------------------------
// 	* C. Use intensive anticipation as control	
//	
// 	if (`i'!=3) & (`i'!=4) {
// 		qui reghdfe `depvar' viol_dsc viol_dsc_l4  ///
// 		opebitda_aa booklev intexpense_aa networth_seqq currentratio mkt_to_book ///
// 		ho2_* ho3_* hol4_*  ///
// 		if query_covfut_wc_any_hi_l1_l4 == 0 & !missing(query_covfut_wc_any_hi_l1_l4), absorb(sic2 datefq) cluster(gvkey)
// 	}
// 	else {
// 		qui reghdfe `depvar' viol_dsc viol_dsc_l4 `depvar'_l1  ///
// 		opebitda_aa booklev intexpense_aa networth_seqq currentratio mkt_to_book ///
// 		ho2_* ho3_* hol4_*  ///
// 		if query_covfut_wc_any_hi_l1_l4 == 0 & !missing(query_covfut_wc_any_hi_l1_l4), absorb(sic2 datefq) cluster(gvkey)
// 	}
//	
// 	scalar num_clusters = e(N_clust)
//	
// 	qui sum viol_dsc if ///
// 		query_covfut_wc_any_hi_l1_l4 == 0 & !missing(query_covfut_wc_any_hi_l1_l4) & viol_dsc==1 ///
// 		& !missing(`depvar') & has_controls==1
// 	scalar nviol = `r(N)'
//	
// 	est store c1_`i'
// 	qui estadd loc firm "\checkmark"
// 	qui estadd loc controls "\checkmark"
// 	estadd scalar num_clusters = num_clusters
// 	estadd scalar nviol = nviol	
//	
	*-----------------------------------------------------------------
	* D. Drop sample where anticipation occurs in t-1 to t-4
	
	if (`i'!=3) & (`i'!=4) {
			qui reghdfe `depvar' viol_dsc  viol_dsc_l4 ///
			opebitda_aa booklev intexpense_aa networth_seqq currentratio mkt_to_book ///
			ho2_* ho3_* hol4_*  ///
			if query_covfut_any_l1_l4==0 & !missing(query_covfut_any_l1_l4), absorb(sic2 datefq) cluster(gvkey)	
		}
	else {
		qui reghdfe `depvar' viol_dsc  viol_dsc_l4 `depvar'_l1 ///
		opebitda_aa booklev intexpense_aa networth_seqq currentratio mkt_to_book ///
		ho2_* ho3_* hol4_*  ///
		if query_covfut_any_l1_l4==0 & !missing(query_covfut_any_l1_l4), absorb(sic2 datefq) cluster(gvkey)	
	}

	scalar num_clusters = e(N_clust)
	
	qui sum viol_dsc if query_covfut_any_l1_l4==0 & viol_dsc==1 & !missing(`depvar') & has_controls==1
	scalar nviol = `r(N)'

	est store d1_`i'

	qui estadd loc firm "\checkmark"	
	qui estadd loc controls "\checkmark"	
	estadd scalar num_clusters = num_clusters
	estadd scalar nviol = nviol

	
	loc ++i
}

* employment growth (annual files) -- add to the first panel
preserve 
	use "$datdir/my_combined_variables_annual_aws_jfi_check", clear  
	xtset gvkey fyear 
	gen viol_dsc_l1 = l1.viol_dsc
	destring sic2, replace
	
	gen has_controls = !missing(viol_dsc_l1) & !missing(opebitda_aa) ///
	& !missing(booklev) & !missing(intexpense_aa) & !missing(networth_seqq) ///
	& !missing(currentratio) & !missing(mkt_to_book) ///
	& !missing(hol1_booklev) & !missing(hol1_intexpense_aa) & !missing(hol1_networth_seqq) ///
	& !missing(hol1_currentratio) & !missing(hol1_mkt_to_book)
	
	gen f4logemployment = f4.logemployment - logemployment
	
	keep if sample_flag_any==1
	
	loc depvarlist emp_growth
	loc i = 5
	foreach depvar in `depvarlist' {
	
		*-----------------------------------------------------------------
		* A. Baseline (Full sample)
		qui reghdfe `depvar' viol_dsc viol_dsc_l1 ///
			opebitda_aa booklev intexpense_aa networth_seqq currentratio mkt_to_book ///
			ho2_* ho3_* hol1_* ///
			if !missing(query_covfut_any_l1_l1), absorb(sic2 fyear) cluster(gvkey)
			
		qui sum viol_dsc if !missing(query_covfut_any_l1_l1) & viol_dsc==1 & !missing(`depvar') & has_controls==1
		scalar nviol = `r(N)'	
			
		scalar num_clusters = e(N_clust)
		est store a1_`i'
		qui estadd loc firm "\checkmark"
		qui estadd loc controls "\checkmark"
		estadd scalar num_clusters = num_clusters
		estadd scalar nviol = nviol
		
// 		*-----------------------------------------------------------------
// 		* B. Use anticipation as control 
//		
// 		qui reghdfe `depvar' viol_dsc viol_dsc_l1 query_covfut_any_l1_l1 ///
// 			opebitda_aa booklev intexpense_aa networth_seqq currentratio mkt_to_book ///
// 			ho2_* ho3_* hol1_*  ///
// 			if !missing(query_covfut_any_l1_l1), absorb(sic2 fyear) cluster(gvkey)
//		
// 		scalar num_clusters = e(N_clust)
// 		qui sum viol_dsc if !missing(query_covfut_any_l1_l1) & viol_dsc==1 ///
// 			& !missing(`depvar') & has_controls==1
// 		scalar nviol = `r(N)'
//		
// 		est store b1_`i'
// 		qui estadd loc firm "\checkmark"
// 		qui estadd loc controls "\checkmark"
// 		estadd scalar num_clusters = num_clusters
// 		estadd scalar nviol = nviol
			
	// 	*-----------------------------------------------------------------
	// 	* C. Use intensive anticipation as control	
	//	
	// 	qui reghdfe `depvar' viol_dsc viol_dsc_l1 ///
	// 		opebitda_aa booklev intexpense_aa networth_seqq currentratio mkt_to_book ///
	// 		ho2_* ho3_* hol1_*  ///
	// 		if query_covfut_wc_any_hi_l1_l1==0 & !missing(query_covfut_wc_any_hi_l1_l1), absorb(sic2 fyear) cluster(gvkey)
	//	
	// 	scalar num_clusters = e(N_clust)
	//	
	// 	qui sum viol_dsc if ///
	// 		query_covfut_wc_any_hi_l1_l1==0 & !missing(query_covfut_wc_any_hi_l1_l1) & viol_dsc==1 ///
	// 		& !missing(`depvar') & has_controls==1
	// 	scalar nviol = `r(N)'
	//	
	// 	est store c1_`i'
	// 	qui estadd loc firm "\checkmark"
	// 	qui estadd loc controls "\checkmark"
	// 	estadd scalar num_clusters = num_clusters
	// 	estadd scalar nviol = nviol		
	//			
		*-----------------------------------------------------------------
		* D. Drop sample where anticipation occurs in t-1 (annual)
		qui reghdfe `depvar' viol_dsc  viol_dsc_l1 ///
				opebitda_aa booklev intexpense_aa networth_seqq currentratio mkt_to_book ///
				ho2_* ho3_* hol1_*  ///
				if query_covfut_any_l1_l1==0 & !missing(query_covfut_any_l1_l1), absorb(sic2 fyear) cluster(gvkey)	
		
		qui sum viol_dsc if query_covfut_any_l1_l1==0 & viol_dsc==1 & !missing(`depvar') & has_controls==1
		scalar nviol = `r(N)'
		
		scalar num_clusters = e(N_clust)
		est store d1_`i'
		qui estadd loc firm "\checkmark"	
		qui estadd loc controls "\checkmark"	
		estadd scalar num_clusters = num_clusters
		estadd scalar nviol = nviol

	loc i = `i'+1
	
	}
	
restore 

esttab a1_*, keep(viol_dsc)
esttab d1_*, keep(viol_dsc)

**--------------------------------------------------------------------
* 2. financing variables

loc depvarlist f4logtotdebt f4tot_debt_growth_aa f4logequitypay f4cashhold f4logdrawnrevolver		

loc i = 1
foreach depvar in `depvarlist' {
	
	*-----------------------------------------------------------------
	* A. Baseline (Full sample)
	
	qui reghdfe `depvar' viol_dsc viol_dsc_l4 ///
		opebitda_aa booklev intexpense_aa networth_seqq currentratio mkt_to_book ///
		ho2_* ho3_* hol4_*  ///
		if !missing(query_covfut_any_l1_l4), absorb(sic2 datefq) cluster(gvkey)

	scalar num_clusters = e(N_clust)
	
	qui sum viol_dsc if ///
		!missing(query_covfut_any_l1_l4) & viol_dsc==1 ///
		& !missing(`depvar') & has_controls==1
	scalar nviol = `r(N)'
	
	est store a2_`i'
	qui estadd loc firm "\checkmark"
	qui estadd loc controls "\checkmark"
	estadd scalar num_clusters = num_clusters
	estadd scalar nviol = nviol
	
// 	*-----------------------------------------------------------------
// 	* B. Use anticipation as control 
//	
// 	qui reghdfe `depvar' viol_dsc viol_dsc_l4 query_covfut_any_l1_l4 ///
// 		opebitda_aa booklev intexpense_aa networth_seqq currentratio mkt_to_book ///
// 		ho2_* ho3_* hol4_*  ///
// 		if !missing(query_covfut_any_l1_l4), absorb(sic2 datefq) cluster(gvkey)
//	
//
// 	scalar num_clusters = e(N_clust)
//	
// 	qui sum viol_dsc if ///
// 		!missing(query_covfut_any_l1_l4) & viol_dsc==1 ///
// 		& !missing(`depvar') & has_controls==1
// 	scalar nviol = `r(N)'
//	
// 	est store b2_`i'
// 	qui estadd loc firm "\checkmark"
// 	qui estadd loc controls "\checkmark"
// 	estadd scalar num_clusters = num_clusters
// 	estadd scalar nviol = nviol
		
	
// 	*-----------------------------------------------------------------
// 	* C. Use intensive anticipation as control	
//	
// 	qui reghdfe `depvar' viol_dsc viol_dsc_l4 ///
// 		opebitda_aa booklev intexpense_aa networth_seqq currentratio mkt_to_book ///
// 		ho2_* ho3_* hol4_*  ///
// 		if query_covfut_wc_any_hi_l1_l4==0 & !missing(query_covfut_wc_any_hi_l1_l4), absorb(sic2 datefq) cluster(gvkey)
//	
// 	scalar num_clusters = e(N_clust)
//	
// 	qui sum viol_dsc if ///
// 		query_covfut_wc_any_hi_l1_l4==0 & !missing(query_covfut_wc_any_hi_l1_l4) & viol_dsc==1 ///
// 		& !missing(`depvar') & has_controls==1
// 	scalar nviol = `r(N)'
//	
// 	est store c2_`i'
// 	qui estadd loc firm "\checkmark"
// 	qui estadd loc controls "\checkmark"
// 	estadd scalar num_clusters = num_clusters
// 	estadd scalar nviol = nviol		
//	
//	
	*-----------------------------------------------------------------
	* D. Drop sample where anticipation occurs in t-1 to t-4
	
	qui reghdfe `depvar' viol_dsc  viol_dsc_l4 ///
		opebitda_aa booklev intexpense_aa networth_seqq currentratio mkt_to_book ///
		ho2_* ho3_* hol4_*  ///
		if query_covfut_any_l1_l4==0 & !missing(query_covfut_any_l1_l4), absorb(sic2 datefq) cluster(gvkey)	

	scalar num_clusters = e(N_clust)
	
	qui sum viol_dsc if query_covfut_any_l1_l4==0 & viol_dsc==1 & !missing(`depvar') & has_controls==1
	scalar nviol = `r(N)'

	est store d2_`i'

	qui estadd loc firm "\checkmark"	
	qui estadd loc controls "\checkmark"	
	estadd scalar num_clusters = num_clusters
	estadd scalar nviol = nviol

	
	loc ++i
}

esttab a2_*, keep(viol_dsc)
esttab d2_*, keep(viol_dsc)

**--------------------------------------------------------------------
* 3. operating variables

loc depvarlist f4ncocf_aa_ann f4logsale f4logopcost f4rating_downgrade f4bankruptcy_filing

loc i = 1
foreach depvar in `depvarlist' {
	
	*-----------------------------------------------------------------
	* A. Baseline (Full sample)
	
	qui reghdfe `depvar' viol_dsc viol_dsc_l4 ///
		opebitda_aa booklev intexpense_aa networth_seqq currentratio mkt_to_book ///
		ho2_* ho3_* hol4_*  ///
		if !missing(query_covfut_any_l1_l4), absorb(sic2 datefq) cluster(gvkey)

	scalar num_clusters = e(N_clust)
	
	qui sum viol_dsc if ///
		!missing(query_covfut_any_l1_l4) & viol_dsc==1 ///
		& !missing(`depvar') & has_controls==1
	scalar nviol = `r(N)'
	
	est store a3_`i'
	qui estadd loc firm "\checkmark"
	qui estadd loc controls "\checkmark"
	estadd scalar num_clusters = num_clusters
	estadd scalar nviol = nviol
	
// 	*-----------------------------------------------------------------
// 	* B. Use anticipation as control 
//	
// 	qui reghdfe `depvar' viol_dsc viol_dsc_l4 query_covfut_any_l1_l4 ///
// 		opebitda_aa booklev intexpense_aa networth_seqq currentratio mkt_to_book ///
// 		ho2_* ho3_* hol4_*  ///
// 		if !missing(query_covfut_any_l1_l4), absorb(sic2 datefq) cluster(gvkey)
//	
//
// 	scalar num_clusters = e(N_clust)
//	
// 	qui sum viol_dsc if ///
// 		!missing(query_covfut_any_l1_l4) & viol_dsc==1 ///
// 		& !missing(`depvar') & has_controls==1
// 	scalar nviol = `r(N)'
//	
// 	est store b3_`i'
// 	qui estadd loc firm "\checkmark"
// 	qui estadd loc controls "\checkmark"
// 	estadd scalar num_clusters = num_clusters
// 	estadd scalar nviol = nviol
		
	
// 	*-----------------------------------------------------------------
// 	* C. Use intensive anticipation as control	
//	
// 	qui reghdfe `depvar' viol_dsc viol_dsc_l4 ///
// 		opebitda_aa booklev intexpense_aa networth_seqq currentratio mkt_to_book ///
// 		ho2_* ho3_* hol4_*  ///
// 		if query_covfut_wc_any_hi_l1_l4==0 & !missing(query_covfut_wc_any_hi_l1_l4), absorb(sic2 datefq) cluster(gvkey)
//	
// 	scalar num_clusters = e(N_clust)
//	
// 	qui sum viol_dsc if ///
// 		query_covfut_wc_any_hi_l1_l4==0 & !missing(query_covfut_wc_any_hi_l1_l4) & viol_dsc==1 ///
// 		& !missing(`depvar') & has_controls==1
// 	scalar nviol = `r(N)'
//	
// 	est store c3_`i'
// 	qui estadd loc firm "\checkmark"
// 	qui estadd loc controls "\checkmark"
// 	estadd scalar num_clusters = num_clusters
// 	estadd scalar nviol = nviol		

	*-----------------------------------------------------------------
	* D. Drop sample where anticipation occurs in t-1 to t-4
	
	qui reghdfe `depvar' viol_dsc  viol_dsc_l4 ///
		opebitda_aa booklev intexpense_aa networth_seqq currentratio mkt_to_book ///
		ho2_* ho3_* hol4_*  ///
		if query_covfut_any_l1_l4==0 & !missing(query_covfut_any_l1_l4), absorb(sic2 datefq) cluster(gvkey)	

	scalar num_clusters = e(N_clust)
	
	qui sum viol_dsc if query_covfut_any_l1_l4==0 & viol_dsc==1 & !missing(`depvar') & has_controls==1
	scalar nviol = `r(N)'

	est store d3_`i'

	qui estadd loc firm "\checkmark"	
	qui estadd loc controls "\checkmark"	
	estadd scalar num_clusters = num_clusters
	estadd scalar nviol = nviol

	
	loc ++i
}

esttab a3_*, keep(viol_dsc)
esttab d3_*, keep(viol_dsc)


**--------------------------------------------------------------------
* 4. access to credit (split by loan type: revolver vs term loan)

loc depvarlist f4r_avg_termloan f4loan_amount_termloan f4r_avg_revolver f4loan_amount_revolver f4amend_any

loc i = 1
foreach depvar in `depvarlist' {
	
	*-----------------------------------------------------------------
	* A. Baseline (Full sample)
	
	qui reghdfe `depvar' viol_dsc viol_dsc_l4 ///
		opebitda_aa booklev intexpense_aa networth_seqq currentratio mkt_to_book ///
		ho2_* ho3_* hol4_*  ///
		if !missing(query_covfut_any_l1_l4), absorb(sic2 datefq) cluster(gvkey)

	scalar num_clusters = e(N_clust)
	
	qui sum viol_dsc if ///
		!missing(query_covfut_any_l1_l4) & viol_dsc==1 ///
		& !missing(`depvar') & has_controls==1
	scalar nviol = `r(N)'
	
	est store a4_`i'
	qui estadd loc firm "\checkmark"
	qui estadd loc controls "\checkmark"
	estadd scalar num_clusters = num_clusters
	estadd scalar nviol = nviol
	
// 	*-----------------------------------------------------------------
// 	* B. Use anticipation as control 
//	
// 	qui reghdfe `depvar' viol_dsc viol_dsc_l4 query_covfut_any_l1_l4 ///
// 		opebitda_aa booklev intexpense_aa networth_seqq currentratio mkt_to_book ///
// 		ho2_* ho3_* hol4_*  ///
// 		if !missing(query_covfut_any_l1_l4), absorb(sic2 datefq) cluster(gvkey)
//	
//
// 	scalar num_clusters = e(N_clust)
//	
// 	qui sum viol_dsc if ///
// 		!missing(query_covfut_any_l1_l4) & viol_dsc==1 ///
// 		& !missing(`depvar') & has_controls==1
// 	scalar nviol = `r(N)'
//	
// 	est store b4_`i'
// 	qui estadd loc firm "\checkmark"
// 	qui estadd loc controls "\checkmark"
// 	estadd scalar num_clusters = num_clusters
// 	estadd scalar nviol = nviol
		
	
// 	*-----------------------------------------------------------------
// 	* C. Use intensive anticipation as control	
//	
// 	qui reghdfe `depvar' viol_dsc viol_dsc_l4 ///
// 		opebitda_aa booklev intexpense_aa networth_seqq currentratio mkt_to_book ///
// 		ho2_* ho3_* hol4_*  ///
// 		if query_covfut_wc_any_hi_l1_l4==0 & !missing(query_covfut_wc_any_hi_l1_l4), absorb(sic2 datefq) cluster(gvkey)
//	
// 	scalar num_clusters = e(N_clust)
//	
// 	qui sum viol_dsc if ///
// 		query_covfut_wc_any_hi_l1_l4==0 & !missing(query_covfut_wc_any_hi_l1_l4) & viol_dsc==1 ///
// 		& !missing(`depvar') & has_controls==1
// 	scalar nviol = `r(N)'
//	
// 	est store c4_`i'
// 	qui estadd loc firm "\checkmark"
// 	qui estadd loc controls "\checkmark"
// 	estadd scalar num_clusters = num_clusters
// 	estadd scalar nviol = nviol		
//		
//	
	*-----------------------------------------------------------------
	* D. Drop sample where anticipation occurs in t-1 to t-4
	
	qui reghdfe `depvar' viol_dsc  viol_dsc_l4 ///
		opebitda_aa booklev intexpense_aa networth_seqq currentratio mkt_to_book ///
		ho2_* ho3_* hol4_*  ///
		if query_covfut_any_l1_l4==0 & !missing(query_covfut_any_l1_l4), absorb(sic2 datefq) cluster(gvkey)	

	scalar num_clusters = e(N_clust)
	
	qui sum viol_dsc if query_covfut_any_l1_l4==0 & viol_dsc==1 & !missing(`depvar') & has_controls==1
	scalar nviol = `r(N)'

	est store d4_`i'

	qui estadd loc firm "\checkmark"	
	qui estadd loc controls "\checkmark"	
	estadd scalar num_clusters = num_clusters
	estadd scalar nviol = nviol

	
	loc ++i
}

esttab a4_*, keep(viol_dsc)
esttab d4_*, keep(viol_dsc)


*** combine all variables

* Panel A: Full Sample - investment activities
esttab a1_* using "$outdir/regression_violation_0_dscan_may2025.tex", ///
       keep(viol_dsc) mtitles("$\Delta$ Log(Asset)" "$\Delta$ Log(PPE)" "Capx/Asset" "CashAcq/Asset" "$\Delta$ Employment") ///
       se(3) b(3) label compress starlevels(* 0.10 ** 0.05 *** 0.01) ///
       stats(N, fmt(0) layout(@) ///
             labels("Observations")) ///
	   replace fragment posthead("\addlinespace \midrule  \multicolumn{3}{l}{\textit{Panel A: Full sample}} & & & \\ ")

* Panel B: Anticipation as control - investment activities 
esttab d1_* using "$outdir/regression_violation_0_dscan_may2025.tex", ///
       keep(viol_dsc) nomtitle nonum ///
       se(3) b(3) label compress starlevels(* 0.10 ** 0.05 *** 0.01) ///
       stats(N, fmt(0) layout(@) ///
             labels("Observations")) ///
       append fragment posthead("\addlinespace \midrule \addlinespace \multicolumn{3}{l}{\textit{Panel B: Exclude any anticipation}} & & & \\ ") postfoot("\addlinespace \midrule  \addlinespace")
	   
* Panel C: Full sample - financing activity
esttab a2_* using "$outdir/regression_violation_0_dscan_may2025.tex", ///
       keep(viol_dsc) mtitles("$\Delta$ Log(Debt)" "$\Delta$  NDI/Assets" "$\Delta$ Log(Payout)" "$\Delta$ Cash/Asset" "$\Delta$ Log(DrawnRev)") nonum ///
       se(3) b(3) label compress starlevels(* 0.10 ** 0.05 *** 0.01) ///
       stats(N, fmt(0) layout(@) ///
             labels("Observations")) ///
	   append fragment posthead("\addlinespace \midrule  \multicolumn{3}{l}{\textit{Panel A: Full sample}} & & & \\ ")

* Panel B: Anticipation as control financing activity 
esttab d2_* using "$outdir/regression_violation_0_dscan_may2025.tex", ///
       keep(viol_dsc) nomtitle nonum ///
       se(3) b(3) label compress starlevels(* 0.10 ** 0.05 *** 0.01) ///
       stats(N, fmt(0) layout(@) ///
             labels("Observations")) ///
       append fragment posthead("\addlinespace \midrule \addlinespace \multicolumn{3}{l}{\textit{Panel B: Exclude any anticipation}} & & & \\ ") postfoot("\addlinespace \midrule  \addlinespace")




* Panel A: Operating Perforamnce (Full Sample)
esttab a3_* using "$outdir/regression_violation_0_dscan_may2025.tex", ///
       keep(viol_dsc) mtitles("$\Delta$ CashFlow/Asset" "$\Delta$ Log(Sale)" "$\Delta$ Log(OpCost)" "1(Downgrade)" "1(Default)") nonum ///
       se(3) b(3) label compress starlevels(* 0.10 ** 0.05 *** 0.01) ///
       stats(N, fmt(0) layout(@) ///
             labels("Observations")) ///
	   append fragment posthead("\addlinespace \midrule  \multicolumn{3}{l}{\textit{Panel A: Full sample}} & & & \\ ")

* Panel B: Operating Performance (Exclude any anticipation)
esttab d3_* using "$outdir/regression_violation_0_dscan_may2025.tex", ///
       keep(viol_dsc) nomtitle nonum ///
       se(3) b(3) label compress starlevels(* 0.10 ** 0.05 *** 0.01) ///
       stats(N, fmt(0) layout(@) ///
             labels("Observations")) ///
       append fragment posthead("\addlinespace \midrule \addlinespace \multicolumn{3}{l}{\textit{Panel B: Exclude any anticipation}} & & & \\ ") postfoot("\addlinespace \midrule   \addlinespace")

* Panel C: Credit Access (Full Sample)	   
esttab a4_* using "$outdir/regression_violation_0_dscan_may2025.tex", ///
       keep(viol_dsc) mtitles("$\Delta$ Spread (TL)" "$\Delta$ Amount (TL)" "$\Delta$ Spread (CL)" "$\Delta$ Amount (CL)" "1\{Amend Terms\}") nonum ///
       se(3) b(3) label compress starlevels(* 0.10 ** 0.05 *** 0.01) ///
       stats(N, fmt(0) layout(@) ///
             labels("Observations")) ///
	   append fragment posthead("\addlinespace \midrule  \multicolumn{3}{l}{\textit{Panel A: Full sample}} & & & \\ ")

* Panel D: Credit Acess (Exclude any anticipation)
esttab d4_* using "$outdir/regression_violation_0_dscan_may2025.tex", ///
       keep(viol_dsc) nomtitle nonum ///
       se(3) b(3) label compress starlevels(* 0.10 ** 0.05 *** 0.01) ///
       stats(N, fmt(0) layout(@) ///
             labels("Observations")) ///
       append fragment posthead("\addlinespace \midrule  \multicolumn{3}{l}{\textit{Panel B: Exclude any anticipation}} & & & \\ ")



*****

	
