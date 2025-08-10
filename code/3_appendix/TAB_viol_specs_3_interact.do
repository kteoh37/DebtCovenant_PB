// Tabulate interaction specification results
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
gen viol_confirmed_org_l4 = l4.viol_confirmed_org
gen capx_spend_aa_ann_l1 = l1.capx_spend_aa*4 
gen acquisitions_aa_ann_l1 = l1.acquisitions_aa*4 

* indicator for observation with all controls
gen has_controls = !missing(viol_confirmed_org_l4) & !missing(opebitda_aa) ///
	& !missing(booklev) & !missing(intexpense_aa) & !missing(networth_seqq) ///
	& !missing(currentratio) & !missing(mkt_to_book) ///
	& !missing(hol4_booklev) & !missing(hol4_intexpense_aa) & !missing(hol4_networth_seqq) ///
	& !missing(hol4_currentratio) & !missing(hol4_mkt_to_book)
	

* interaction with core covenant indicator
gen int_viol_query = 	viol_confirmed_org * query_covfut_any_l1_l4 
gen int_viol_l4_query = viol_confirmed_org_l4 * query_covfut_any_l1_l4
gen int_viol_query_hi = viol_confirmed_org * query_covfut_wc_any_hi_l1_l4
gen int_viol_l4_query_hi = viol_confirmed_org_l4 * query_covfut_wc_any_hi_l1_l4
	
	
********** 
* keep relevant sample 
keep if sample_flag_any==1

**********
* label variables
label var viol_confirmed_org "Covenant Violation"
label var int_viol_query "Violation x CovConcerns (Any)"
label var int_viol_query_hi "Violation x CovConcerns (Intensive)"


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
	* A. Interact with intensive concerns
	
	if (`i'!=3) & (`i'!=4) {
		qui reghdfe `depvar' viol_confirmed_org viol_confirmed_org_l4  ///
		int_viol_query_hi int_viol_l4_query_hi ///
		i.query_covfut_wc_any_hi_l1_l4##( ///
		c.opebitda_aa c.booklev c.intexpense_aa c.networth_seqq c.currentratio c.mkt_to_book ///
		c.ho2_* c.ho3_* c.hol4_*)  ///
		if !missing(query_covfut_wc_any_hi_l1_l4), ///
		absorb(sic2#i.query_covfut_wc_any_hi_l1_l4 datefq#i.query_covfut_wc_any_hi_l1_l4) cluster(gvkey)
	}
	else {
		qui reghdfe `depvar' viol_confirmed_org viol_confirmed_org_l4 ///
		int_viol_query_hi int_viol_l4_query_hi ///
		i.query_covfut_wc_any_hi_l1_l4##( ///
		c.opebitda_aa c.booklev c.intexpense_aa c.networth_seqq c.currentratio c.mkt_to_book ///
		c.ho2_* c.ho3_* c.hol4_* c.`depvar'_l1)   ///
		if !missing(query_covfut_wc_any_hi_l1_l4), ///
		absorb(sic2#i.query_covfut_wc_any_hi_l1_l4 datefq#i.query_covfut_wc_any_hi_l1_l4) cluster(gvkey)
	}
	
	est store c1_`i'
	qui estadd loc firm "\checkmark"
	qui estadd loc controls "\checkmark"
	
	*-----------------------------------------------------------------
	* B. Interact with any concerns
	
	if (`i'!=3) & (`i'!=4) {
		qui reghdfe `depvar' viol_confirmed_org  viol_confirmed_org_l4 ///
		int_viol_query int_viol_l4_query ///
		i.query_covfut_any_l1_l4##( ///
		c.opebitda_aa c.booklev c.intexpense_aa c.networth_seqq c.currentratio c.mkt_to_book ///
		c.ho2_* c.ho3_* c.hol4_*)  ///
		if !missing(query_covfut_any_l1_l4), ///
		absorb(sic2#i.query_covfut_any_l1_l4 datefq#i.query_covfut_any_l1_l4) cluster(gvkey)	
		}
	else {
		qui reghdfe `depvar' viol_confirmed_org  viol_confirmed_org_l4 ///
		int_viol_query int_viol_l4_query ///
		i.query_covfut_any_l1_l4##( ///
		c.opebitda_aa c.booklev c.intexpense_aa c.networth_seqq c.currentratio c.mkt_to_book ///
		c.ho2_* c.ho3_* c.hol4_* c.`depvar'_l1)  ///
		if !missing(query_covfut_any_l1_l4), ///
		absorb(sic2#i.query_covfut_any_l1_l4 datefq#i.query_covfut_any_l1_l4) cluster(gvkey)	
	}

	est store d1_`i'

	qui estadd loc firm "\checkmark"	
	qui estadd loc controls "\checkmark"	

	loc ++i
}

* employment growth (annual files) -- add to the first panel
preserve 
	use "$datdir/my_combined_variables_annual_aws_jfi_check", clear  
	xtset gvkey fyear 
	gen viol_confirmed_org_l1 = l1.viol_confirmed_org
	destring sic2, replace
	
	gen has_controls = !missing(viol_confirmed_org_l1) & !missing(opebitda_aa) ///
	& !missing(booklev) & !missing(intexpense_aa) & !missing(networth_seqq) ///
	& !missing(currentratio) & !missing(mkt_to_book) ///
	& !missing(hol1_booklev) & !missing(hol1_intexpense_aa) & !missing(hol1_networth_seqq) ///
	& !missing(hol1_currentratio) & !missing(hol1_mkt_to_book)
	
	gen int_viol_query       = viol_confirmed_org * query_covfut_any_l1_l1 
	gen int_viol_l1_query    = viol_confirmed_org_l1 * query_covfut_any_l1_l1
	gen int_viol_query_hi    = viol_confirmed_org * query_covfut_wc_any_hi_l1_l1
	gen int_viol_l1_query_hi = viol_confirmed_org * query_covfut_wc_any_hi_l1_l1
			
	keep if sample_flag_any==1
	
	loc depvarlist emp_growth
	loc i = 5
	foreach depvar in `depvarlist' {
			
		*-----------------------------------------------------------------
		* A. Interact with intensive concerns
		
		qui reghdfe `depvar' viol_confirmed_org viol_confirmed_org_l1 ///
			int_viol_query_hi int_viol_l1_query_hi ///
			i.query_covfut_wc_any_hi_l1_l1##( ///	
			c.opebitda_aa c.booklev c.intexpense_aa c.networth_seqq c.currentratio c.mkt_to_book ///
			c.ho2_* c.ho3_* c.hol1_*)  ///
			if !missing(query_covfut_wc_any_hi_l1_l1), ///
			absorb(sic2#i.query_covfut_wc_any_hi_l1_l1 fyear#i.query_covfut_wc_any_hi_l1_l1) cluster(gvkey)
		
		est store c1_`i'
		qui estadd loc firm "\checkmark"
		qui estadd loc controls "\checkmark"
		estadd scalar num_clusters = num_clusters
		estadd scalar nviol = nviol		
				
		*-----------------------------------------------------------------
		* B. Interact with any concerns
		
		qui reghdfe `depvar' viol_confirmed_org viol_confirmed_org_l1 ///
			int_viol_query int_viol_l1_query ///
			i.query_covfut_any_l1_l1##( ///
			c.opebitda_aa c.booklev c.intexpense_aa c.networth_seqq c.currentratio c.mkt_to_book ///
			c.ho2_* c.ho3_* c.hol1_*) ///
			if !missing(query_covfut_any_l1_l1), ///
			absorb(sic2#i.query_covfut_any_l1_l1 fyear#i.query_covfut_any_l1_l1) cluster(gvkey)
		
		est store d1_`i'
		qui estadd loc firm "\checkmark"
		qui estadd loc controls "\checkmark"
	
		loc i = `i'+1
	
	}
	
restore 


**--------------------------------------------------------------------
* 2. financing variables

loc depvarlist f4logtotdebt f4tot_debt_growth_aa f4logequitypay f4cashhold f4logdrawnrevolver			

loc i = 1
foreach depvar in `depvarlist' {
	
	*-----------------------------------------------------------------
	* A. Interact with intensive concerns
	
	qui reghdfe `depvar' viol_confirmed_org viol_confirmed_org_l4  ///
		int_viol_query_hi int_viol_l4_query_hi ///
		i.query_covfut_wc_any_hi_l1_l4##( ///
		c.opebitda_aa c.booklev c.intexpense_aa c.networth_seqq c.currentratio c.mkt_to_book ///
		c.ho2_* c.ho3_* c.hol4_*)  ///
		if !missing(query_covfut_wc_any_hi_l1_l4), ///
		absorb(sic2#i.query_covfut_wc_any_hi_l1_l4 datefq#i.query_covfut_wc_any_hi_l1_l4) cluster(gvkey)

	est store c2_`i'
	qui estadd loc firm "\checkmark"
	qui estadd loc controls "\checkmark"
	
	*-----------------------------------------------------------------
	* B. Interact with any concerns 
	
	qui reghdfe `depvar' viol_confirmed_org  viol_confirmed_org_l4 ///
		int_viol_query int_viol_l4_query ///
		i.query_covfut_any_l1_l4##( ///
		c.opebitda_aa c.booklev c.intexpense_aa c.networth_seqq c.currentratio c.mkt_to_book ///
		c.ho2_* c.ho3_* c.hol4_*)  ///
		if !missing(query_covfut_any_l1_l4), ///
		absorb(sic2#i.query_covfut_any_l1_l4 datefq#i.query_covfut_any_l1_l4) cluster(gvkey)	
		
	est store d2_`i'
	qui estadd loc firm "\checkmark"	
	qui estadd loc controls "\checkmark"	
	
	loc ++i
}


**--------------------------------------------------------------------
* 3. operating variables

loc depvarlist f4ncocf_aa_ann f4logsale f4logopcost f4rating_downgrade f4bankruptcy_filing

loc i = 1
foreach depvar in `depvarlist' {
	
	*-----------------------------------------------------------------
	* A. Interact with intensive concerns
	
	qui reghdfe `depvar' viol_confirmed_org viol_confirmed_org_l4  ///
		int_viol_query_hi int_viol_l4_query_hi ///
		i.query_covfut_wc_any_hi_l1_l4##( ///
		c.opebitda_aa c.booklev c.intexpense_aa c.networth_seqq c.currentratio c.mkt_to_book ///
		c.ho2_* c.ho3_* c.hol4_*)  ///
		if !missing(query_covfut_wc_any_hi_l1_l4), ///
		absorb(sic2#i.query_covfut_wc_any_hi_l1_l4 datefq#i.query_covfut_wc_any_hi_l1_l4) cluster(gvkey)

	est store c3_`i'
	qui estadd loc firm "\checkmark"
	qui estadd loc controls "\checkmark"
	
	*-----------------------------------------------------------------
	* B. Interact with any concerns 
	
	qui reghdfe `depvar' viol_confirmed_org  viol_confirmed_org_l4 ///
		int_viol_query int_viol_l4_query ///
		i.query_covfut_any_l1_l4##( ///
		c.opebitda_aa c.booklev c.intexpense_aa c.networth_seqq c.currentratio c.mkt_to_book ///
		c.ho2_* c.ho3_* c.hol4_*)  ///
		if !missing(query_covfut_any_l1_l4), ///
		absorb(sic2#i.query_covfut_any_l1_l4 datefq#i.query_covfut_any_l1_l4) cluster(gvkey)	
		
	est store d3_`i'
	qui estadd loc firm "\checkmark"	
	qui estadd loc controls "\checkmark"

	
	loc ++i
}


**--------------------------------------------------------------------
* 4. access to credit (split by loan type: revolver vs term loan)

loc depvarlist f4r_avg_termloan f4loan_amount_termloan f4r_avg_revolver f4loan_amount_revolver f4amend_any

loc i = 1
foreach depvar in `depvarlist' {

	*-----------------------------------------------------------------
	* A. Interact with intensive concerns
	
	qui reghdfe `depvar' viol_confirmed_org viol_confirmed_org_l4  ///
		int_viol_query_hi int_viol_l4_query_hi ///
		i.query_covfut_wc_any_hi_l1_l4##( ///
		c.opebitda_aa c.booklev c.intexpense_aa c.networth_seqq c.currentratio c.mkt_to_book ///
		c.ho2_* c.ho3_* c.hol4_*)  ///
		if !missing(query_covfut_wc_any_hi_l1_l4), ///
		absorb(sic2#i.query_covfut_wc_any_hi_l1_l4 datefq#i.query_covfut_wc_any_hi_l1_l4) cluster(gvkey)

	est store c4_`i'
	qui estadd loc firm "\checkmark"
	qui estadd loc controls "\checkmark"
	
	*-----------------------------------------------------------------
	* B. Interact with any concerns 
	
	qui reghdfe `depvar' viol_confirmed_org  viol_confirmed_org_l4 ///
		int_viol_query int_viol_l4_query ///
		i.query_covfut_any_l1_l4##( ///
		c.opebitda_aa c.booklev c.intexpense_aa c.networth_seqq c.currentratio c.mkt_to_book ///
		c.ho2_* c.ho3_* c.hol4_*)  ///
		if !missing(query_covfut_any_l1_l4), ///
		absorb(sic2#i.query_covfut_any_l1_l4 datefq#i.query_covfut_any_l1_l4) cluster(gvkey)	
		
	est store d4_`i'
	qui estadd loc firm "\checkmark"	
	qui estadd loc controls "\checkmark"
	
	loc ++i
}

**------------------------------------------------------------------------------
**------------------------------------------------------------------------------
* Panel A: Full Sample - investment activities
esttab c1_* using "$outdir/regression_violation_1_interact_may2025.tex", ///
       keep(viol_confirmed_org int_viol_query_hi) mtitles("$\Delta$ Log(Asset)" "$\Delta$ Log(PPE)" "Capx/Asset" "CashAcq/Asset" "$\Delta$ Employment") ///
       se(3) b(3) label compress starlevels(* 0.10 ** 0.05 *** 0.01) ///
       stats(N, fmt(0) layout(@) ///
             labels("Observations")) ///
	   replace fragment posthead(" \midrule  \multicolumn{3}{l}{\textit{Panel A: Intensive anticipation}} & & & \\ ")

* Panel B: Anticipation as control - investment activities 
esttab d1_* using "$outdir/regression_violation_1_interact_may2025.tex", ///
       keep(viol_confirmed_org int_viol_query) nomtitle nonum ///
       se(3) b(3) label compress starlevels(* 0.10 ** 0.05 *** 0.01) ///
       stats(N, fmt(0) layout(@) ///
             labels("Observations")) ///
       append fragment posthead(" \midrule  \multicolumn{3}{l}{\textit{Panel B: Any anticipation}} & & & \\ ") postfoot(" \midrule ")
	   
* Panel C: Full sample - financing activity
esttab c2_* using "$outdir/regression_violation_1_interact_may2025.tex", ///
       keep(viol_confirmed_org int_viol_query_hi) mtitles("$\Delta$ Log(Debt)" "$\Delta$  NDI/Assets" "$\Delta$ Log(Payout)" "$\Delta$ Cash/Asset" "$\Delta$ Log(DrawnRev)") nonum ///
       se(3) b(3) label compress starlevels(* 0.10 ** 0.05 *** 0.01) ///
       stats(N, fmt(0) layout(@) ///
             labels("Observations")) ///
	   append fragment posthead(" \midrule  \multicolumn{3}{l}{\textit{Panel A: Intensive anticipation}} & & & \\ ")

* Panel B: Anticipation as control financing activity 
esttab d2_* using "$outdir/regression_violation_1_interact_may2025.tex", ///
       keep(viol_confirmed_org int_viol_query) nomtitle nonum ///
       se(3) b(3) label compress starlevels(* 0.10 ** 0.05 *** 0.01) ///
       stats(N, fmt(0) layout(@) ///
             labels("Observations")) ///
       append fragment posthead(" \midrule  \multicolumn{3}{l}{\textit{Panel B: Any anticipation}} & & & \\ ") postfoot(" \midrule   ")




* Panel A: Operating Perforamnce (Full Sample)
esttab c3_* using "$outdir/regression_violation_2_interact_may2025.tex", ///
       keep(viol_confirmed_org int_viol_query_hi) mtitles("$\Delta$ CashFlow/Asset" "$\Delta$ Log(Sale)" "$\Delta$ Log(OpCost)" "1(Downgrade)" "1(Default)") ///
       se(3) b(3) label compress starlevels(* 0.10 ** 0.05 *** 0.01) ///
       stats(N, fmt(0) layout(@) ///
             labels("Observations")) ///
	   replace fragment posthead(" \midrule  \multicolumn{3}{l}{\textit{Panel A: Intensive anticipation}} & & & \\ ")

* Panel B: Operating Performance (Exclude any anticipation)
esttab d3_* using "$outdir/regression_violation_2_interact_may2025.tex", ///
       keep(viol_confirmed_org int_viol_query) nomtitle nonum ///
       se(3) b(3) label compress starlevels(* 0.10 ** 0.05 *** 0.01) ///
       stats(N, fmt(0) layout(@) ///
             labels("Observations")) ///
       append fragment posthead("\midrule  \multicolumn{3}{l}{\textit{Panel B: Any anticipation}} & & & \\ ") postfoot("\midrule   ")

* Panel C: Credit Access (Full Sample)	   
esttab c4_* using "$outdir/regression_violation_2_interact_may2025.tex", ///
       keep(viol_confirmed_org int_viol_query_hi) mtitles("$\Delta$ Spread (TL)" "$\Delta$ Amount (TL)" "$\Delta$ Spread (CL)" "$\Delta$ Amount (CL)" "1\{Amend Terms\}") nonum ///
       se(3) b(3) label compress starlevels(* 0.10 ** 0.05 *** 0.01) ///
       stats(N, fmt(0) layout(@) ///
             labels("Observations")) ///
	   append fragment posthead(" \midrule  \multicolumn{3}{l}{\textit{Panel A: Intensive anticipation}} & & & \\ ")

* Panel D: Credit Acess (Exclude any anticipation)
esttab d4_* using "$outdir/regression_violation_2_interact_may2025.tex", ///
       keep(viol_confirmed_org int_viol_query) nomtitle nonum ///
       se(3) b(3) label compress starlevels(* 0.10 ** 0.05 *** 0.01) ///
       stats(N, fmt(0) layout(@) ///
             labels("Observations")) ///
       append fragment posthead(" \midrule  \multicolumn{3}{l}{\textit{Panel B: Any anticipation}} & & & \\ ")


*****

	
