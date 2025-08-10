// generate master link table
// gvkey-cik-cusip-repid

clear 
global maindir "/Users/kenteoh/Dropbox/debt_covenant"
global rawdir "$maindir/rawdata_jfi_fin"
global datdir "$maindir/data_jfi_fin"

// ------ load quarterly compustat file 
use gvkey cusip datadate conm rdq fyearq fqtr fic using "$rawdir/wrds/header_comp_fundq", clear 
drop if missing(cusip)
gen cusip6 = substr(cusip,1,6)
keep if fic == "USA"


loc varlist datadate rdq 
foreach var in `varlist' {
	gen tmp = dofc(`var')
	format %td tmp
	drop `var'
	rename tmp `var'
}

// if missing fqtr, replace with quarter of data date
replace fqtr = quarter(datadate) if missing(fqtr)
gen datefq = yq(fyearq, fqtr)
format %tq datefq

// manage duplicates 
bys gvkey datadate (fyearq): keep if _n == _N 	 // drop duplicate data date, keep latest fiscal year (duplicates due to changing fiscal year)
bys gvkey fyearq fqtr (datadate): keep if _n == 1 // keep oldest fiscal quarter if duplicate 

// reporting quarter -- set to be datadate + 3 months following fiscal end if missing
replace rdq = dofm(mofd(datadate)+4)-1 if missing(rdq)
format %td rdq
gen daterq = yq(year(rdq), quarter(rdq))
format %tq daterq 


// ----- load cusip-cik link table
preserve 
	use gvkey cik fndate lndate n10k using "$rawdir/wrds/header_gvkey_cik_linktable.dta", clear
	rename *, lower
	
	loc varlist fndate lndate 
	foreach var in `varlist' {
		gen tmp = dofc(`var')
		format %td tmp
		drop `var'
		rename tmp `var'
	}
	
	bys gvkey cik: egen fndate0 = min(fndate)
	bys gvkey cik: egen lndate0 = max(lndate)
	format %td fndate0 lndate0
	
	// housekeeping
	drop if missing(cik)
	bys gvkey cik (n10k): keep if _n == _N
	keep gvkey cik fndate lndate

	tempfile ciklink
	save `ciklink'
restore 

joinby gvkey using `ciklink', unmatched(master)
drop _merge

// manage duplicates

// 1. datadate within filing date range
gduplicates tag gvkey fyearq fqtr, gen(dup_flag)
gen match_flag = (((datadate - fndate) >= 0) & ((lndate - datadate) >= 0)) | missing(fndate) | datadate >= mdy(7,1,2021)
gegen any_match_flag = max(match_flag), by(gvkey fyearq fqtr)

gen keep_flag = (dup_flag == 0) | (dup_flag > 0 & match_flag == 1) | (dup_flag > 0 & any_match_flag == 0) 
drop if keep_flag == 0
drop dup_flag match_flag any_match_flag keep_flag

// 2. if duplicates, keep first entry by fndate 
replace fndate = mdy(12,31,2021) if missing(fndate)
bys gvkey fyearq fqtr (fndate): keep if _n == 1
drop fndate lndate


// ----- load cusip-factset entity link table
preserve 

use "$rawdir/xwalk/reportid_cusip_calldat_xwalk", clear 
drop if missing(cusip)
gen cusip6 = substr(cusip,1,6)

gen daterq = yq(year(calldat), quarter(calldat))
format %tq daterq
gsort cusip6 daterq calldat

// manage duplicates
// 1. if multiple entries in a quarter, check if next quarter present. if not shift last entry to next quarter
bys cusip6 (calldat): gen next_rq = daterq[_n] - daterq[_n-1]
bys cusip6 (calldat): replace daterq = daterq-1 if next_rq>1 & next_rq[_n+1]==0
format %tq daterq
drop next_rq

// 2. if still duplicates, then just keep larger file
bys cusip6 daterq (filesize): keep if _n == _N // keep larger file in each reporting year quarter
drop filesize


tempfile factset
save `factset'

restore 

merge m:1 cusip6 daterq using `factset', keep(1 3) nogen
gsort gvkey fyearq fqtr 


// ----- load gvkey permno match 
preserve 

use "$rawdir/xwalk/wrds_ccm_gvkey_permno", clear
	* from wrds compustat-crsp merged file 
rename *, lower

* keep smaller set of variables
keep gvkey lpermno datadate fqtr fyearq

// if missing fqtr, replace with quarter of data date
replace fqtr = quarter(datadate) if missing(fqtr)

// this is user generated from fyearq fqtr 
gen datefq = yq(fyearq,fqtr)
format %tq datefq

// manage duplicates 
bys gvkey datadate (fyearq): keep if _n == _N 	 // drop duplicate data date, keep latest fiscal year (duplicates due to changing fiscal year)
bys gvkey fyearq fqtr (datadate): keep if _n == 1 // keep oldest fiscal quarter if duplicate 

rename lpermno permno

tempfile ccm 
save `ccm'

restore 

merge 1:1 gvkey datadate fyearq fqtr using `ccm', keep(1 3) nogen


// save file
save "$datdir/my_master_header.dta", replace

// save as text
export delimited using "$datdir/my_master_header.txt", replace delimiter("|")
