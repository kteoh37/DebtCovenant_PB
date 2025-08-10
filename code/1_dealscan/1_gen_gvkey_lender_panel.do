// Builds a panel linking Dealscan loans to lending institutions using Compustat gvkeys.
// Restricts to lead arrangers and cleans dates to examine lender exposure over time.
=======
// Generate panel dataset of lenders from Dealscan

clear 
global maindir "/path/to/project"
global rawdir "$maindir/rawdata_jfi_fin"
global datdir "$maindir/data_jfi_fin"

use "$datdir/dealscan_borrower_lender", clear
keep if !missing(gvkey)
drop borrower_id
drop lender_parent_name
drop is_*
keep if lead_arranger==1 // keep only lead arranger
drop lead_arranger

* generate two digit code 
replace sic_code = "0000" if sic_code==""
gen sic2 = substr(sic_code,1,2)

* format date variables
loc varlist earliest_active_date latest_maturity_date 
foreach var in `varlist' {
	gen tmp = dofc(`var')
	format %td tmp
	drop `var'
	rename tmp `var'
}

* fix maturity end date
* replace maturity date if missing and active 
replace latest_maturity_date = mdy(12,31,2021) if missing(latest_maturity_date) & deal_active=="Yes"
* drop non-active loans with no ending maturity date
drop if missing(latest_maturity_date) 
* replace maturity date if greater than 12/31/2021
replace latest_maturity_date = mdy(12,31,2021) if latest_maturity_date > mdy(12,31,2021)
replace earliest_active_date = mdy(1,1,2002) if earliest_active_date < mdy(1,1,2002) // start of panel
drop if latest_maturity_date <= mdy(1,1,2002)
drop deal_active

* fix duplicates (multiple borrower ids match to gvkey)
gegen grpid = group(lender_id gvkey)
bys grpid (earliest_active_date latest_maturity_date): gen aux1 = earliest_active_date[1]
bys grpid (earliest_active_date latest_maturity_date): gen aux2 = latest_maturity_date[_N]
format %td aux1 aux2
drop earliest* latest* 
rename aux1 earliest_active_date
rename aux2 latest_maturity_date 
bys grpid: keep if _n==1

* reshape to long
rename (earliest_active_date latest_maturity_date) (t1 t2)
reshape long t, i(grpid) j(start_end)
gen datecq = yq(year(t), quarter(t))
format %tq datecq
drop start_end t

* construct panel
gduplicates tag grpid datecq, gen(dup)
drop if dup>0 // few cases where lender-borrower pair only valid for one quarter
drop dup
xtset grpid datecq
tsfill 

loc varlist lender_id lender_parent_id gvkey lender_name sic2 sic_code 
foreach var in `varlist' {
	bys grpid (datecq): carryforward `var', replace
}
drop grpid

order gvkey datecq lender_id
gsort gvkey datecq lender_id

save "$datdir/dealscan_gvkey_lender_panel.dta", replace


