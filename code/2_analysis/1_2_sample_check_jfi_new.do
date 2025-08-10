* Performs diagnostic checks on the quarterly combined dataset.
* Creates anticipated violation indicators and lagged measures at the firm-quarter level.

clear 
global maindir "/path/to/project"
global rawdir "$maindir/rawdata_jfi_fin"
global datdir "$maindir/data_jfi_fin"

* load data
use "$datdir/my_combined_variables_quarterly_aws_jfi", clear 
xtset gvkey datefq

**** generate new variables
* rename variables
rename viol_confirmed viol_confirmed_org
replace viol_confirmed_org = . if datecq>=yq(2017,1)

** keyword-based anticipated violations
loc varlist query_covfut query_covfut_sec query_cov query_cov_sec 
foreach var in `varlist' {
	gen tmp = `var'>0 if !missing(`var')
	drop `var'
	rename tmp `var'
}
egen query_covfut_any = rowmax(query_covfut query_covfut_sec)
egen query_cov_any = rowmax(query_cov query_cov_sec)

** keyword-based anticipated violations (intensive margin)
loc varlist query_covfut query_cov
foreach var in `varlist' {
	egen `var'_wc_any = rowmax(`var'_wc `var'_wc_sec)
	
	qui sum `var'_wc_any if `var'_wc_any>0, d 
	gen `var'_wc_any_hi = (`var'_wc_any> `r(p50)' ) if !missing(`var'_wc_any)

}

* indicator of anticipation in past four quarters
gen query_covfut_l1_l1 = l1.query_covfut
gen query_covfut_any_l1_l1 = l1.query_covfut_any
gen query_covfut_wc_any_l1_l1 = l1.query_covfut_wc_any
gen query_covfut_wc_any_hi_l1_l1 = l1.query_covfut_wc_any_hi
forval i = 2/4 {
	loc j = `i'-1
	
	* kw based - earnings call sample only
	gen query_covfut_l`i' = l`i'.query_covfut
	egen query_covfut_l1_l`i' = rowmax(query_covfut_l1_l`j' query_covfut_l`i')
	
	* kw based. - both earnings call and sec filings
	gen query_covfut_any_l`i' = l`i'.query_covfut_any 
	egen query_covfut_any_l1_l`i' = rowmax(query_covfut_any_l1_l`j' query_covfut_any_l`i')
	
	* kw based - both ec and sec filing - intensity (top quantile)
	gen query_covfut_wc_any_hi_l`i' = l`i'.query_covfut_wc_any_hi 
	egen query_covfut_wc_any_hi_l1_l`i' = rowmax(query_covfut_wc_any_hi_l1_l`j' query_covfut_wc_any_hi_l`i')
	
	* kw based - both ec and sec filing - intensity (continous)
	gen query_covfut_wc_any_l`i' = l`i'.query_covfut_wc_any 
	egen query_covfut_wc_any_l1_l`i' = rowmax(query_covfut_wc_any_l1_l`j' query_covfut_wc_any_l`i')	
	
}
drop query_covfut_l2 query_covfut_l3 query_covfut_l4
drop query_covfut_any_l2 query_covfut_any_l3 query_covfut_any_l4
drop query_covfut_wc_any_hi_l2 query_covfut_wc_any_hi_l3 query_covfut_wc_any_hi_l4
drop query_covfut_wc_any_l2 query_covfut_wc_any_l3 query_covfut_wc_any_l4

****** other control variables
* generate downgrade indicator
gen rating_downgrade = (rating_numeric > l1.rating_numeric) if !missing(rating_numeric)
gen rating_default = (rating_numeric == 22) if !missing(rating_numeric)

* generate indicator for change in credit spread and loan amount
replace r_avg = . if r_avg <0 
replace r_avg_revolver = . if r_avg_revolver <0 
replace r_avg_termloan = . if r_avg_termloan <0

gen f4r_avg = f4.r_avg - r_avg 
gen f4r_avg_revolver = f4.r_avg_revolver - r_avg_revolver 
gen f4r_avg_termloan = f4.r_avg_termloan - r_avg_termloan 
gen logloan_amount = log(tranche_amount_sum)
gen logloan_amount_revolver = log(tranche_amount_sum_revolver)
gen logloan_amount_termloan = log(tranche_amount_sum_termloan)
gen f4loan_amount = f4.logloan_amount - logloan_amount
gen f4loan_amount_termloan = f4.logloan_amount_termloan - logloan_amount_termloan
gen f4loan_amount_revolver = f4.logloan_amount_revolver - logloan_amount_revolver
gen f4amend_rate = (amend_rate==1) | (f1.amend_rate==1) | (f2.amend_rate==1) | (f3.amend_rate==1) | (f4.amend_rate==1) ///
	if !missing(amend_rate) | !missing(f1.amend_rate) | !missing(f2.amend_rate) | !missing(f3.amend_rate) | !missing(f4.amend_rate)
gen f4amend_amount = (amend_amount==1) | (f1.amend_amount==1) | (f2.amend_amount==1) | (f3.amend_amount==1) | (f4.amend_amount==1) ///
	if !missing(amend_amount) | !missing(f1.amend_amount) | !missing(f2.amend_amount) | !missing(f3.amend_amount) | !missing(f4.amend_amount)	
gegen f4amend_any = rowmax(f4amend_rate f4amend_amount)
	
* generate bankruptcy resolution/ filing indicators 
gegen max_datecq = max(datecq), by(gvkey)
loc varlist bankruptcy_filing bankruptcy_resolution
foreach var in `varlist' {
	egen aux_ = rowmin(`var'_yq max_datecq) if !missing(`var'_yq) // bankruptcy filed, but date not in panel
	gen `var'_ind = (datecq==aux_) if !missing(`var'_yq)
	drop aux `var'_yq
	
	replace `var'_ind = 0 if missing(`var'_ind) & !missing(drawnrevolver_na) // these are companies with data in capiq but never filed bankruptcy
}
replace bankruptcy_filing_ind = 1 if (rating_default==1) 

* higher order controls
loc varlist opebitda_aa booklev intexpense_aa networth_seqq currentratio mkt_to_book
foreach var in `varlist' {
	gen ho2_`var' = `var'^2
	gen ho3_`var' = `var'^3
	gen hol4_`var' = l4.`var'
}

****** sample restrictions
gen init_sample_flag_long = !missing(cov_viol_ind) & !missing(query_covfut_any)
gen init_sample_flag_any = !missing(viol_confirmed_org) & !missing(query_covfut_any)
gen init_sample_flag_ec = !missing(viol_confirmed_org) & !missing(query_covfut)
gen nss_flag = (fic=="USA") & !inrange(sich, 6000, 6999) & !missing(atq) & !missing(logsale) & !missing(mcap) & !missing(datecq)
gen date_flag = inrange(datefq, yq(2002,1), yq(2016,4))
gen date_flag_long = inrange(datefq, yq(2002,1), yq(2020,1))
gen sample_flag_long = init_sample_flag_long & nss_flag==1 & date_flag_long==1
gen sample_flag_any	= init_sample_flag_any==1 & nss_flag==1 & date_flag==1
gen sample_flag_ec = init_sample_flag_ec==1 & nss_flag==1 & date_flag==1
	
save "$datdir/my_combined_variables_quarterly_aws_jfi_check", replace

