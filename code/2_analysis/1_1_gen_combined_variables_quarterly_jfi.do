* Creates a comprehensive firm-quarter dataset combining Compustat, covenant, earnings call,
* EDGAR, Dealscan, and rating information while retaining covenant-level detail.

clear 
global maindir "/path/to/project"
global rawdir "$maindir/rawdata_jfi_fin"
global datdir "$maindir/data_jfi_fin"

* load headerfile 
use "$datdir/my_master_header.dta", clear
keep gvkey fyearq fqtr cik conm datadate rdq cusip permno // justkeep id
gen cusip8 = substr(cusip, 1, 8)
drop cusip 
rename cusip8 cusip 

* merge with compustat variables
merge 1:1 gvkey fyearq fqtr using "$datdir/compustat_combined_variables_quarterly_aws_3_jfi.dta", keep(1 3) nogen
replace datefq = yq(fyearq,fqtr) if missing(datefq)
destring gvkey, replace

// * merge with ibes sue 
// merge 1:1 cusip datadate using "$datdir/ibes_sue_import", keep(1 3) nogen

* merge with griffin, nini, becher's covenant violation data 
merge m:1 gvkey datadate using "$datdir/griffin_violdata", keep(1 3) nogen

* merge with factset earnings calls data
merge m:1 cusip fyear fqtr using "$datdir/my_query_with_cusip_match", keep(1 3) nogen
gen call_date = dofc(call_datetime_utc)
format %td call_date

* merge with nss violation data (parsed from sec)
merge m:1 gvkey datadate using "$datdir/my_edgar_new_combined_jfi_may2025", keep(1 3) nogen

* merge with dealscan spreads data 
merge m:1 gvkey datecq using "$datdir/dealscan_gvkey_loan_type_panel.dta", keep(1 3) nogen
merge m:1 gvkey datecq using "$datdir/dealscan_gvkey_tranche_type_panel.dta", keep(1 3) nogen

* merge with sp ratings 
merge m:1 gvkey fyearq fqtr using "$datdir/CapIQ_SP_Rating_processed", keep(1 3) nogen

* merge with recession dates
gen datem = ym(year(dofq(datecq)), month(dofq(datecq)))+2 // end of quarter month
format %tm datem
merge m:1 datem using "$rawdir/misc/fred_recession_dates", keep(1 3) nogen

* merge with tarek hassan's risk measures
merge m:1 gvkey call_date using "$datdir/hassan_riskmeasures_processed", keep(1 3) nogen

* merge with fred data 
merge m:1 datecq using "$rawdir/misc/fred_macro_series", keep(1 3) nogen

* merge with bankruptcy dates (from capital IQ)
merge m:1 gvkey using "$datdir/CapIQ_bankruptcy_filing", keep(1 3) nogen
merge m:1 gvkey using "$datdir/CapIQ_bankruptcy_resolution", keep(1 3) nogen

* merge with Dealscan covenant data (updated Feb 2025)
preserve 
	use "$datdir/my_distance_to_threshold_quarterly_new_aws_2.dta", clear
	
	* indicators for presence of core covenants
	gen core_covenant = 0 if !missing(covenanttype)
	replace core_covenant = 1 if inlist(covenanttype, "Min. Current Ratio", "Min. Net Worth", "Min. Tangible Net Worth")
	gegen core_covenant_max = max(core_covenant), by(gvkey datefq)
	drop core_covenant 
	rename core_covenant_max core_covenant
	
	* indicator for violation
	gegen viol_dsc = max(viol), by(gvkey datefq)
	
	bys gvkey datefq (ratio_diff): keep if _n==1 // keep tightest covenant
	keep gvkey datefq ratio_diff core_covenant viol_dsc 
	tempfile ds
	save `ds', replace
restore 
merge m:1 gvkey datefq using `ds', keep(1 3) nogen

save "$datdir/my_combined_variables_quarterly_aws_jfi.dta", replace
