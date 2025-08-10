* Performs diagnostic checks on the annual combined dataset.
* Generates anticipated violation indicators and lagged variables for summary analysis.

clear 
global maindir "/path/to/project"
global rawdir "$maindir/rawdata_jfi_fin"
global datdir "$maindir/data_jfi_fin"

* load data
use "$datdir/my_combined_variables_annual_aws_jfi", clear 
xtset gvkey fyear

**** generate new variables
* rename variables
rename viol_confirmed viol_confirmed_org
replace viol_confirmed_org = . if fyear>=2017
// rename (anticipate_score call_anticipate_score) (anticipate_score_sec anticipate_score_call)

** keyword-based anticipated violations
loc varlist query_covfut query_covfut_sec query_cov query_cov_sec 
foreach var in `varlist' {
	gen tmp = `var'>0 if !missing(`var')
	drop `var'
	rename tmp `var'
}
egen query_covfut_any = rowmax(query_covfut query_covfut_sec)
egen query_cov_any = rowmax(query_cov query_cov_sec)

** keyword-based anticipated violations (intensive)
loc varlist query_covfut query_cov
foreach var in `varlist' {
	egen `var'_wc_any = rowmax(`var'_wc `var'_wc_sec)
	
	qui sum `var'_wc_any if `var'_wc_any>0, d 
	gen `var'_wc_any_hi = (`var'_wc_any> `r(p50)' ) if !missing(`var'_wc_any)

}

* indicator of anticipation in past year
gen query_covfut_l1_l1 = l1.query_covfut
gen query_covfut_any_l1_l1 = l1.query_covfut_any
gen query_covfut_wc_any_hi_l1_l1 = l1.query_covfut_wc_any_hi
gen query_covfut_wc_any_l1_l1 = l1.query_covfut_wc_any

* higher order controls (argh...)
loc varlist opebitda_aa booklev intexpense_aa networth_seqq currentratio mkt_to_book
foreach var in `varlist' {
	gen ho2_`var' = `var'^2
	gen ho3_`var' = `var'^3
	gen hol1_`var' = l1.`var'
}

****** sample restrictions
gen init_sample_flag = !missing(viol_confirmed_org) & !missing(query_covfut)
gen init_sample_flag_long = !missing(cov_viol_ind) & !missing(query_covfut)
gen init_sample_flag_any = !missing(viol_confirmed_org) & !missing(query_covfut_any)
gen nss_flag = (fic=="USA") & !inrange(sich, 6000, 6999) & !missing(at) & !missing(logsale) & !missing(mcap) & !missing(fyear)
gen date_flag = inrange(fyear, 2002, 2016)
gen date_flag_long = inrange(fyear, 2002, 2020)
gen sample_flag = init_sample_flag==1 & nss_flag==1 & date_flag==1
gen sample_flag_long = init_sample_flag_long & nss_flag==1 & date_flag_long==1
gen sample_flag_any = init_sample_flag_any==1 & nss_flag==1 & date_flag==1
	
tostring sich, replace
gen sic2 = substr(sich, 1,2)
	
save "$datdir/my_combined_variables_annual_aws_jfi_check", replace

