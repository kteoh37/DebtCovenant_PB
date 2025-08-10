// Generates a panel of Dealscan tranche types linked to Compustat gvkeys.
// Restricts to LIBOR tranches and standardizes dates to analyze tranche-level activity.
clear 
global maindir "/path/to/project"
global rawdir "$maindir/rawdata_jfi_fin"
global datdir "$maindir/data_jfi_fin"

use "$datdir/dealscan_borrower_tranche", clear
keep if !missing(gvkey)
keep if base_reference_rate=="LIBOR"
drop borrower_id
drop orig_maturity_date deal_amount

winsor2 nlenders, cut(0 99) trim replace

* generate two digit code 
replace sic_code = "0000" if sic_code==""
gen sic2 = substr(sic_code,1,2)

* format date variables
gen earliest_active_date  = tranche_active_date 
loc varlist earliest_active_date latest_maturity_date tranche_active_date
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

* replace tranche_o_a with sequences 
gen amend_seq = .
replace amend_seq = 0 if tranche_o_a == "Origination"
forval i = 1/36 {
	replace amend_seq = `i' if tranche_o_a == "Amendment `i'"
}
drop tranche_o_a

* collapse to deal level
gegen grpid = group(lpc_tranche_id tranche_active_date)
bys grpid (earliest_active_date latest_maturity_date): gen aux1 = earliest_active_date[1]
bys grpid (earliest_active_date latest_maturity_date): gen aux2 = latest_maturity_date[_N]
format %td aux1 aux2
drop earliest* latest* 
rename aux1 earliest_active_date
rename aux2 latest_maturity_date 
bys grpid: keep if _n==1

* reshape to long
destring lpc_tranche_id, replace
rename (earliest_active_date latest_maturity_date) (t1 t2)
reshape long t, i(grpid) j(start_end)
gen datecq = yq(year(t), quarter(t))
format %tq datecq
drop start_end t

* generate loan type indicator 
gen loantype = 0
replace loantype=1 if has_revolver==1
replace loantype=2 if has_termloan==1 // some small overlap where tranche is both term loan and revolver 

* construct panel
gduplicates tag grpid datecq, gen(dup)
drop if dup>0 // few cases where lender-borrower pair only valid for one quarter
drop dup
xtset grpid datecq
tsfill 

loc varlist lpc_tranche_id gvkey sic2 sic_code trad_bank inst_loan private_loan inst_loan_ib institutional termA termB levloan covlite nlenders inst_loan_bny amend_seq tranche_active_date early_nego deal_amount has_revolver has_termloan base_reference_rate all_in_spread_drawn_bps loantype all_in_spread_undrawn_bps tranche_amount
foreach var in `varlist' {
	bys grpid (datecq): carryforward `var', replace
}

* compute firm-quarter level weighted average of spreads (added Nov 6, 2024)
gegen tranche_amount_sum = sum(tranche_amount), by(gvkey datecq loantype)
gen r_wgt = tranche_amount / tranche_amount_sum * all_in_spread_drawn_bps 
gen ru_wgt = tranche_amount / tranche_amount_sum * all_in_spread_undrawn_bps 
gegen r_avg = sum(r_wgt), by(gvkey datecq loantype)
gegen ru_avg = sum(ru_wgt), by(gvkey datecq loantype)

* collapse to firm-quarter-loantype level
destring sic2 sic_code, replace
gcollapse (max) tranche_amount_sum r_avg ru_avg ///
	, by(gvkey datecq loantype)

* 	convert to firm quarter level
reshape wide tranche_amount_sum r_avg ru_avg, i(gvkey datecq) j(loantype)
	
loc varlist 	tranche_amount_sum r_avg ru_avg
foreach var in `varlist' {
	rename `var'0 `var'_other
	rename `var'1 `var'_revolver
	rename `var'2 `var'_termloan
}

* winsorize 
loc varlist r_avg_termloan r_avg_revolver r_avg_other ru_avg_termloan ru_avg_revolver ru_avg_other ///
	tranche_amount_sum_other tranche_amount_sum_revolver tranche_amount_sum_termloan
foreach var in `varlist' {
	winsor2 `var', cuts(1 99) replace trim 
	replace `var' = . if `var' <0
}
	
order gvkey datecq 
gsort gvkey datecq 

save "$datdir/dealscan_gvkey_tranche_type_panel.dta", replace
