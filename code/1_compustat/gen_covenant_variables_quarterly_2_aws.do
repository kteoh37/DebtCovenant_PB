// Derive covenant-related ratios from quarterly Compustat financial statements.
// Cleans and deduplicates observations to measure firm covenant slack over time.

clear 
global maindir "/path/to/project"
global rawdir "$maindir/rawdata_jfi_fin"
global datdir "$maindir/data_jfi_fin"

// ------------------------------------------------------
// import compustat data (quarterly)

use "$rawdir/wrds/compustat_fundq_00-20", clear 
drop index
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

// this is user generated from fyearq fqtr 
gen datefq = yq(fyearq,fqtr)
format %tq datefq

// manage duplicates 
bys gvkey datadate (fyearq): keep if _n == _N 	 // drop duplicate data date, keep latest fiscal year (duplicates due to changing fiscal year)
bys gvkey fyearq fqtr (datadate): keep if _n == 1 // keep oldest fiscal quarter if duplicate 

// reporting quarter -- set to be next quarter following fiscal end if missing
replace rdq = datadate + 1 if missing(rdq)
gen daterq = yq(year(rdq), quarter(rdq))
format %tq daterq 

// import some variables from annual compustat (same housekeeping as annual version)
preserve 
	use gvkey datadate fyear ds xrent using "$rawdir/wrds/compustat_funda_00-20", clear 
	
	bys gvkey fyear (datadate): keep if _n == 1
	drop datadate

	rename fyear fyearq 
	
	tempfile annfile 
	save `annfile'
restore 
merge m:1 gvkey fyearq using `annfile', keep(1 3) nogen

// ------------------------------------------------------
// data housekeeping 

* measurement error 
replace saleq = . if saleq < 0 
replace prc = . if abs(prc) < 1
replace atq = . if atq < 0

* correction for operating lease 
* see https://cpb-us-w2.wpmucdn.com/voices.uchicago.edu/dist/7/1291/files/2017/01/lease.pdf
* added May 25, 2023
replace atq = atq - rouantq
replace ppentq = ppentq - rouantq 
replace dlttq = dlttq - llltq
replace dlcq = dlcq - llcq
replace ltq = ltq - (llltq + llcq)
replace lctq = lctq - llcq

// interpolate balance sheet variables 
loc varlist dlttq dlcq atq ltq actq lctq intanq cheq rectq 
foreach var in `varlist' {
	bys gvkey (datefq): ipolate `var' datefq, gen(tmp)
	drop `var'
	rename tmp `var'
}

// set variables to zero if missing
loc varlist xintq
foreach var in `varlist' {
	replace `var' = 0 if missing(`var')
}

// ------------------------------------------------------
// generate covenant variables here 
// following Demerjian-Owens (2016) Table 4

encode gvkey, gen(firm_id)
xtset firm_id datefq

gen intpnq=intpny-l.intpny
replace intpnq=intpny if fqtr==1

// annualize flow variables
gen ann_oibdpq = oibdpq + l1.oibdpq + l2.oibdpq + l3.oibdpq
gen ann_xintq = xintq + l1.xintq + l2.xintq + l3.xintq
gen ann_intpnq = intpnq + l1.intpnq + l2.intpnq + l3.intpnq 

// generate financial ratios 
gen cov1 	= (dlttq + dlcq) / ann_oibdpq // debt-to-ebitda
gen cov2 	= (dlttq + dlcq - ds) / ann_oibdpq // senior debt-to-ebitda
gen cov3 	= ann_oibdpq / ann_xintq // interest coverage
gen cov4 	= ann_oibdpq / ann_intpnq // cash interest coverage
gen cov5 	= ann_oibdpq / (ann_xintq + l1.dlcq) // debt service coverage
gen cov6 	= ann_oibdpq / (ann_xintq + l1.dlcq + xrent) // fixed charge coverage
gen cov7 	= ann_oibdpq // minimum ebitda
gen cov8 	= (dlttq + dlcq) / atq // leverage
gen cov9 	= (dltt + dlcq - ds) / atq // senior leverage
gen cov10 	= (dlttq + dlcq) / (atq - intanq - ltq) // debt to net worth
gen cov11 	= (dlttq + dlcq) / (atq - ltq) // debt to equity
gen cov12 	= actq / lctq // current ratio
gen cov13 	= (rectq + cheq) / lctq // quick ratio
gen cov14 	= atq - ltq // minimum net worth
gen cov15 	= atq - intanq - ltq  // minimum tangible net worth

// keep gvkey cusip datefq cov1-cov15 counter1-counter15
keep gvkey cusip datefq cov1-cov15

// ------------------------------------------------------
// reshape to long format 

reshape long cov, i(gvkey datefq) j(covenanttype) 

// rename covenant 
gen covenanttype_str = ""
replace covenanttype_str = "Max. Debt to EBITDA" if covenanttype == 1
replace covenanttype_str = "Max. Senior Debt to EBTIDA" if covenanttype == 2
replace covenanttype_str = "Min. Interest Coverage" if covenanttype == 3
replace covenanttype_str = "Min. Cash Interest Coverage" if covenanttype == 4
replace covenanttype_str = "Min. Debt Service Coverage" if covenanttype == 5
replace covenanttype_str = "Min. Fixed Charge Coverage" if covenanttype == 6
replace covenanttype_str = "Min. EBITDA" if covenanttype == 7
replace covenanttype_str = "Max. Leverage ratio" if covenanttype == 8
replace covenanttype_str = "Max. Senior Leverage" if covenanttype == 9
replace covenanttype_str = "Max. Debt to Tangible Net Worth" if covenanttype == 10
replace covenanttype_str = "Max. Debt to Equity" if covenanttype == 11
replace covenanttype_str = "Min. Current Ratio" if covenanttype == 12
replace covenanttype_str = "Min. Quick Ratio" if covenanttype == 13
replace covenanttype_str = "Min. Net Worth" if covenanttype == 14
replace covenanttype_str = "Min. Tangible Net Worth" if covenanttype == 15

// housekeeping
rename cov currentratio
// rename counter currentratio_counterfact
drop covenanttype 
rename covenanttype_str covenanttype
gsort gvkey covenanttype datefq

// do regular winsorizing 
winsor2 currentratio, trim cuts(1 99) by(covenanttype) // save trimmed values as new variable 

save "$datdir/compustat_covenant_ratios_quarterly_aws.dta", replace
