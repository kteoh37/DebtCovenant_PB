// Creates a panel of Dealscan loan types matched to Compustat gvkeys.
// Cleans maturity dates and lender counts to analyze debt structure by loan category.
=======
// Generate panel dataset of loan types from Dealscan

clear 
global maindir "/path/to/project"
global rawdir "$maindir/rawdata_jfi_fin"
global datdir "$maindir/data_jfi_fin"

use "$datdir/dealscan_borrower_deal", clear
keep if !missing(gvkey)
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
gegen grpid = group(lpc_deal_id tranche_active_date)
bys grpid (earliest_active_date latest_maturity_date): gen aux1 = earliest_active_date[1]
bys grpid (earliest_active_date latest_maturity_date): gen aux2 = latest_maturity_date[_N]
format %td aux1 aux2
drop earliest* latest* 
rename aux1 earliest_active_date
rename aux2 latest_maturity_date 
bys grpid: keep if _n==1

* reshape to long
destring lpc_deal_id, replace
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

loc varlist lpc_deal_id gvkey sic2 sic_code trad_bank inst_loan private_loan inst_loan_ib institutional termA termB levloan covlite nlenders inst_loan_bny amend_seq tranche_active_date early_nego deal_amount deal_amount_converted has_revolver has_termloan base_reference_rate all_in_spread_drawn_bps all_in_spread_undrawn_bps
foreach var in `varlist' {
	bys grpid (datecq): carryforward `var', replace
}

* compute firm-quarter level weighted average of spreads (added Nov 6, 2024)
gegen tranche_amount_sum = sum(deal_amount_converted), by(gvkey datecq)
gen r_wgt = deal_amount_converted / tranche_amount_sum * all_in_spread_drawn_bps if base_reference_rate=="LIBOR"
gen ru_wgt = deal_amount_converted / tranche_amount_sum * all_in_spread_undrawn_bps if base_reference_rate=="LIBOR"
gegen r_avg = sum(r_wgt), by(gvkey datecq)
gegen ru_avg = sum(ru_wgt), by(gvkey datecq)

destring sic2 sic_code, replace
gcollapse (max) sic2 sic_code trad_bank inst_loan private_loan inst_loan_ib inst_loan_bny ///
	institutional termA termB levloan_new=levloan covlite_new=covlite nlenders ///
	deal_amount=deal_amount_converted has_revolver has_termloan tranche_amount_sum r_avg ru_avg ///
	(count) ndeals=lpc_deal_id, by(gvkey datecq)

order gvkey datecq 
gsort gvkey datecq 

save "$datdir/dealscan_gvkey_loan_type_panel.dta", replace

preserve
	gcollapse (mean) covlite termB termA levloan inst_loan inst_loan_bny nlenders deal_amount has_revolver has_termloan r_avg, by(datecq)
	tsset datecq
	keep if inrange(datecq, yq(2002,1), yq(2020,1))
	tsline  r_avg
restore
