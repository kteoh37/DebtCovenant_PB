// this version uses MDA extracted from SEC API

clear 
global maindir "/path/to/project"
global rawdir "$maindir/rawdata_jfi_fin"
global datdir "$maindir/data_jfi_fin"

*----- load master index files from SEC filings 
import delimited using "$rawdir/edgar/edgar_masterhtml1_combined.csv", delimiter("|") clear
keep v1 cik filing_type filing_date report_date company_name main_url
gen fdate = date(filing_date,"YMD")
gen rdate = date(report_date,"YMD")
format %td fdate rdate 
drop filing_date report_date
rename v1 master_idx

tempfile masteridx 
save `masteridx'

*** Merge data files
*----- merge with covenant violation data (v2: post submission version)
// import data
import delimited using "$datdir/edgar_mda_new_violations_2.txt", clear
	// see aws pythons script: extract_secapi_mda_amendments_2
keep master_idx cov_viol_ind
tempfile cov 
save `cov'

use `masteridx', clear
merge 1:1 master_idx using `cov', keep(1 3) nogen
save `masteridx', replace

*----- merge with amendment data (keywords)
// import data
import delimited using "$datdir/edgar_mda_new_amendments_2.txt", clear
keep master_idx amend_rate_ind amend_amount_ind amend_terminate_ind amend_maturity_ind amend_collateral_ind
tempfile amend 
save `amend'

use `masteridx', clear
merge 1:1 master_idx using `amend', keep(1 3) nogen
save `masteridx', replace

*----- merge with anticipation data (keyword)
import delimited using "$datdir/sec_api_mda_covenant_mentions_june2024_update.txt", clear
keep master_idx query_cov_sec query_covfut_sec query_cov_fut_wc query_covenant_wc 
rename (query_covenant_wc query_cov_fut_wc) (query_cov_wc_sec query_covfut_wc_sec)  // added May 2025
tempfile anticipate_kw
save `anticipate_kw'

use `masteridx', clear 
merge 1:1 master_idx using `anticipate_kw', keep(1 3) nogen
save `masteridx', replace

*** Get GVKEY using GVKEY-CIK mapping
*----- get gvkey from WRDS gvkey-cik link
use "$rawdir/wrds/header_gvkey_cik_linktable_update_jul2023.dta", clear
	// raw data file
rename *, lower
keep cik fndate lndate gvkey n10k

drop if missing(gvkey)

* duplicate cik-gvkey: keep maximum range of valid filing dates
bys cik gvkey: egen fndate0 = min(fndate)
bys cik gvkey: egen lndate0 = max(lndate)
format %td fndate0 lndate0
// bys cik gvkey: egen n10k_ = sum(n10k)
drop fndate lndate n10k
bys cik gvkey fndate0 lndate0: keep if _n==_N

destring cik, force replace

tempfile wrds
save `wrds'

*----- merge both files
use `masteridx', clear
merge m:1 cik using `wrds', keep(1 3)
gen match_flag = ((fdate - fndate) >= 0 & (lndate - fdate) >= 0 & _merge==3) | _merge==1
drop if match_flag ==0
drop match_flag
drop _merge
drop fndate0 lndate0

* keep only rows with valid gvkey match
keep if !missing(gvkey)

**** Get unique GVKEY-Report Date (maximum within each duplicate values)
* note: this ignores missing values (i.e. takes numerical values where such values are available)
loc varlist cov_viol_ind amend_rate_ind amend_amount_ind amend_terminate_ind amend_maturity_ind amend_collateral_ind query_cov_sec query_covfut_sec query_cov_wc_sec query_covfut_wc_sec 
foreach var in `varlist' {
	egen aux_`var' = max(`var'), by(gvkey rdate)
	drop `var'
	rename aux_`var' `var' 
}
bys gvkey rdate (fdate): keep if _n==_N

tempfile master 
save `master'

**** Get DataDate
*----- handle rdate-datadate mismatch (not all report dates are end of month dates)
* housekeeping
// drop main_url
drop company_name main_url
destring gvkey, force replace
order gvkey rdate fdate filing_type

* --- merge exact datadate 
preserve 
	* load headerfile 
	use "$datdir/my_master_header.dta", clear
	keep gvkey datadate rdq
	destring gvkey, force replace
	
	* generate relevant variable
	gen flag_quality_sec = 1
	gen date_merge = datadate 
	
	tempfile comp 
	save `comp'
restore 
gen date_merge = rdate
merge 1:1 gvkey date_merge using `comp', keep(1 3) nogen
		// 89 percent / 424,472 successfully merged 

forval m = 0(1)2 {

* datadate i month before rdate
preserve 
	* load headerfile 
	use "$datdir/my_master_header.dta", clear
	keep gvkey datadate rdq
	destring gvkey, force replace
	
	* generate relevant variable 
	gen flag_quality_sec = 2+`m'
	gen date_merge = ym(year(datadate), month(datadate))
	format %tm date_merge 
	
	tempfile comp 
	save `comp'
restore 
cap drop date_merge 
gen date_merge = ym(year(rdate), month(rdate))-`m'
format %tm date_merge 
merge m:1 gvkey date_merge using `comp', keep(1 3 4 5) nogen update

* if duplicate gvkey-date_merge, keep better quality match (if available)
gduplicates tag gvkey date_merge, gen(dup)
egen min_quality_sec = min(flag_quality_sec), by(gvkey date_merge)
replace datadate=. if dup>0 & flag_quality_sec > min_quality_sec
replace rdq=. if dup>0 & flag_quality_sec> min_quality_sec
replace flag_quality_sec=. if dup>0 & flag_quality_sec> min_quality_sec
drop dup min_quality_sec

* datadate i month after rdate
preserve 
	* load headerfile 
	use "$datdir/my_master_header.dta", clear
	keep gvkey datadate rdq
	destring gvkey, force replace
	
	* generate relevant variable 
	gen flag_quality_sec = 2+`m'
	gen date_merge = ym(year(datadate), month(datadate))
	format %tm date_merge 
	
	tempfile comp 
	save `comp'
restore 
cap drop date_merge 
gen date_merge = ym(year(rdate), month(rdate))+`m'
format %tm date_merge 
merge m:1 gvkey date_merge using `comp', keep(1 3 4 5) nogen update

* if duplicate gvkey-date_merge, keep better quality match (if available)
gduplicates tag gvkey date_merge, gen(dup)
egen min_quality_sec = min(flag_quality_sec), by(gvkey date_merge)
replace datadate=. if dup>0 & flag_quality_sec > min_quality_sec
replace rdq=. if dup>0 & flag_quality_sec> min_quality_sec
replace flag_quality_sec=. if dup>0 & flag_quality_sec> min_quality_sec
drop dup min_quality_sec
	
}		

* for those still missing datadate, set as last date of ym(rdate)
cap drop date_merge
gen date_merge =ym(year(rdate), month(rdate))+1
gen aux = dofm(date_merge)-1
format %td aux
replace flag_quality_sec = 5 if missing(datadate)
replace datadate = aux if missing(datadate)
drop aux date_merge

* collapse to unique gvkey datadate, keeping better quality match
loc varlist cov_viol_ind amend_rate_ind amend_amount_ind amend_terminate_ind amend_maturity_ind amend_collateral_ind  query_cov_sec query_covfut_sec query_cov_wc_sec query_covfut_wc_sec
foreach var in `varlist' {
	egen aux_`var' = max(`var'), by(gvkey datadate)
	drop `var'
	rename aux_`var' `var' 
}
bys gvkey datadate (flag_quality_sec): keep if _n==1

*----- housekeeping
drop if missing(datadate)

order gvkey datadate
gsort gvkey datadate
keep gvkey datadate  cov_viol_ind amend_rate_ind amend_amount_ind amend_terminate_ind amend_maturity_ind amend_collateral_ind  query_cov_sec query_covfut_sec filing_type  query_cov_wc_sec query_covfut_wc_sec
save "$datdir/my_edgar_new_combined_jfi_may2025", replace




