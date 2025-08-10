// Converts Dealscan covenant observations into a borrower-quarter panel for analysis.
// Uses preprocessed outputs and reshapes covenant terms to track thresholds over time.

clear 
global maindir "/path/to/project"
global rawdir "$maindir/rawdata_jfi_fin"
global datdir "$maindir/data_jfi_fin"

use "$datdir/dealscan_combined_long_new_2.dta", clear 

keep if !missing(gvkey)
keep if !missing(covenant)
keep if !missing(covthreshold) 

// format date variables
drop index
loc varlist tranche_active_date min_deal_active_date max_deal_maturity_date adj_deal_maturity_date
foreach var in `varlist' {
	gen tmp = dofc(`var')
	format %td tmp
	drop `var'
	rename tmp `var'
}

// drop if no end date to contract
replace adj_deal_maturity_date = mdy(12,31,2021) if missing(adj_deal_maturity_date) & deal_active=="Yes"
drop if missing(adj_deal_maturity_date)

// keep relevant variables
keep lpc_deal_id min_deal_active_date covenant covthreshold adj_deal_maturity_date gvkey 

egen grpid = group(lpc_deal_id covenant min_deal_active_date)

// sanity check
// bys lpc_deal_id covenant: keep if _N > 1
// bys lpc_deal_id covenant (min_deal_active_date): gen flag = (covthreshold!=covthreshold[_n-1]) & _n>1
// gegen maxflag = max(flag), by(lpc_deal_id covenant)

// reshape to panel form
qui sum adj_deal_maturity_date 
replace adj_deal_maturity_date = `r(max)' if missing(adj_deal_maturity_date)

rename (min_deal_active_date adj_deal_maturity_date) (t1 t2)
reshape long t, i(grpid) j(start_end)
gen datecq = yq(year(t), quarter(t))
format %tq datecq

bys grpid datecq (start_end): keep if _n==1
	// duplicate grpid because start and end of contract in same quarter
bys lpc_deal_id covenant datecq (start_end): keep if _n==_N 
	// duplicate lpc_deal_id covenant because end of previous contract overlap start of next contract	
	
bys grpid (start_end): gen orig_ind = 1 if start_end==1
bys grpid: gen flag = 1 if _N==1
bys lpc_deal_id covenant (datecq): replace orig_ind = 1 if flag[_n+1]==1
drop flag 
	
drop grpid 
egen grpid = group(lpc_deal_id covenant)

xtset grpid datecq
tsfill

loc varlist lpc_deal_id covenant covthreshold gvkey
foreach var in `varlist' {
	bys grpid (datecq): carryforward `var', replace
}

// adjustments
replace orig_ind = 0 if missing(orig_ind)

// collapse to firm-quarter 
// keep tightest threshold if duplicate firm-quarter-covenant

// indicate max vs min ratios 
replace covenant = "Min. Net Worth" if covenant == "Net Worth"
replace covenant = "Min. Tangible Net Worth" if covenant == "Tangible Net Worth"
replace covthreshold = covthreshold / 1000000 if inlist(covenant, "Min. Net Worth", "Min. Tangible Net Worth")
gen dir_flag = substr(covenant, 1, 3)

// use tightest constraint if duplicate by firm-quarter-covenanttype
bys gvkey covenant datecq  (covthreshold): gen effective_thres = covthreshold[1] ///
	if dir_flag == "Max"
bys gvkey covenant datecq  (covthreshold): replace effective_thres = covthreshold[_N] ///
	if inlist(dir_flag, "Min")
	
gduplicates drop gvkey covenant datecq , force

keep gvkey datecq covenant effective_thres dir_flag orig_ind 
order gvkey covenant datecq  effective_thres dir_flag
gsort gvkey covenant datecq 

// housekeeping
rename covenant covenanttype



save "$datdir/dealscan_combined_panel.dta", replace






