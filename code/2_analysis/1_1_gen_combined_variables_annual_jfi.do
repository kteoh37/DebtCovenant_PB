*** Build annual dataset by merging Compustat, covenant violation, earnings call, EDGAR,
*** and Dealscan sources to study employment growth effects.
** Updated Nov 5, 2024

* keep important quarterly variables
clear 
global maindir "/path/to/project"
global rawdir "$maindir/rawdata_jfi_fin"
global datdir "$maindir/data_jfi_fin"

* load headerfile 
use "$datdir/my_master_header.dta", clear
keep gvkey fyearq fqtr datadate cusip datefq // justkeep id
gen cusip8 = substr(cusip, 1, 8)
drop cusip 
rename cusip8 cusip 

* housekeeping
destring gvkey, replace

* merge with griffin, nini, becher's covenant violation data 
merge m:1 gvkey datadate using "$datdir/griffin_violdata", keep(1 3) nogen

* merge with factset earnings calls data
merge m:1 cusip fyear fqtr using "$datdir/my_query_with_cusip_match", keep(1 3) nogen
gen call_date = dofc(call_datetime_utc)
format %td call_date

* merge with nss violation data (parsed from sec)
merge m:1 gvkey datadate using "$datdir/my_edgar_new_combined_jfi_may2025", keep(1 3) nogen

* merge with dealscan data (February 2025)
preserve 
	use "$datdir/my_distance_to_threshold_quarterly_new_aws_2.dta", clear
	
	* indicators for presence of core covenants
	gen core_covenant = 0 if !missing(covenanttype)
	replace core_covenant = 1 if inlist(covenanttype, "Min. Current Ratio", "Min. Net Worth", "Min. Tangible Net Worth")
	gegen core_covenant_max = max(core_covenant), by(gvkey datefq)
	drop core_covenant 
	rename core_covenant_max core_covenant
	
	* indicator for violation
	gegen viol_dsc = max(viol), by(gvkey datefq)
	
	bys gvkey datefq (ratio_diff): keep if _n==1 // keep tightest covenant
	keep gvkey datefq core_covenant viol_dsc 
	tempfile ds
	save `ds', replace
restore 

merge m:1 gvkey datefq using `ds', keep(1 3) nogen

** collapse to annual level
gcollapse (max) viol_confirmed query_cov query_covfut cov_viol_ind query_cov_sec query_covfut_sec core_covenant viol_dsc ///
	query_cov_wc_sec query_covfut_wc_sec ///
	, by(gvkey fyearq)

* merge with annual compustat
rename fyearq fyear
merge 1:1 gvkey fyear using "$datdir/compustat_combined_variables_annual_2024_09", keep(1 3) nogen
	
save "$datdir/my_combined_variables_annual_aws_jfi.dta", replace
