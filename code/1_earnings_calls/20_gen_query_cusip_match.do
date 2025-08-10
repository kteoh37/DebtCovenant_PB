* Builds a crosswalk linking FactSet earnings call entity IDs to CUSIPs and Compustat gvkeys.
* Facilitates matching of transcript data to financial records.

clear 
global maindir "/path/to/project"
global rawdir "$maindir/rawdata_jfi_fin"
global datdir "$maindir/data_jfi_fin"
global metdir "$rawdir/factset"

* ------------------------------------------------------------------------
* get entity_id to cusip match (unique cusips)
	
* 1) construct entity_id-cusip crosswalk 

* get fsym_id-cusip crosswalk
import delimited using "$metdir/fsym_id.txt", clear varnames(1) delimiters(",")

* get cusips (merge on fsym_id)
preserve
	import delimited using "$metdir/cusip.txt", clear varnames(1) delimiters(",")
	
	tempfile cusip
	save `cusip'
restore
merge 1:1 fsym_id using `cusip', keep(3) nogen
drop fsym_id

* 2) clean duplicates (unique cusip-entity id)

*  keep those with compustat matches
preserve 
	use "$rawdir/wrds/header_comp_fundq", clear
	keep cusip 
	gduplicates drop cusip, force
	tempfile comp 
	save `comp'
restore 
merge m:1 cusip using `comp', keep(3) nogen

gen cusip8 = substr(cusip, 1, 8)
drop cusip 
rename cusip8 cusip

tempfile cusip_id 
save `cusip_id'

* ------------------------------------------------------------------------

* get reportid - eventid link table 
import delimited using "$metdir/report_id.txt", clear

* merge with call fiscal quarter info 
preserve 
	import delimited using "$metdir/call.txt", clear
	tempfile call 
	save `call'
restore 
merge m:1 event_id using `call', keep(1 3) nogen

* get unique factset_entity_id fiscal_year fiscal_period  (keep latest call)
gsort factset_entity_id fiscal_year fiscal_period
drop if missing(fiscal_year)
drop if missing(fiscal_period)

gen aux = clock(event_datetime, "YMD hms")
drop event_datetime_utc 
rename aux event_datetime_utc
format event_datetime_utc %tc

* if duplicate calls for same fiscal period, select latest call
bys factset_entity_id fiscal_year fiscal_period (event_datetime_utc): keep if _n==_N 

* merge in call query variables (we use the original keyword variables)
preserve 
	use "$datdir/my_query_variable_aws_org_feb2025.dta", clear
	destring report_id, force replace
	tempfile query
	save `query'
restore 
merge 1:1 report_id using `query', keep(1 3) nogen


loc varlist call_nwords call_nsents cov_senti covfut_senti query_covpas ///
	query_cov query_cov_mda query_cov_qa ///
	query_covfut query_covfut_mda query_covfut_qa  
foreach var in `varlist' {
	replace `var' = 0 if missing(`var')
}

* drop if no text parsed (1159 out of 450k calls)
drop if call_nwords==0	
	
gsort factset_entity_id fiscal_year fiscal_period

tempfile call_id 
save `call_id'

* ------------------------------------------------------------------------
* merge the two datasets (unique cusip-fiscal year - fiscal period)
use `call_id', clear 
joinby factset_entity_id using `cusip_id', unmatched(none)
drop if missing(cusip)

drop if inlist(fiscal_period, "5", "A", "Dec", "Mar", "Sep")
destring fiscal_period, force replace
gunique cusip fiscal_year fiscal_period

drop factset_entity_id 
order cusip fiscal_year fiscal_period event_datetime_utc
rename fiscal_year fyearq 
rename fiscal_period fqtr 
rename event_datetime_utc call_datetime_utc

* ------------------------------------------------------------------------
* quality check

* drop calls with multiple cusip-fiscal year- fiscal quarter (< 1 percent of calls)
gduplicates tag report_id, gen(dup)
drop if dup >0 
drop dup 

drop event_id
save "$datdir/my_query_with_cusip_match", replace


