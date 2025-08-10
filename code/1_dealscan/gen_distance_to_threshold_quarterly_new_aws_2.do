// Calculates quarterly distance-to-threshold measures for financial covenants.
// Merges Compustat ratios with Dealscan covenant levels to gauge available slack.

clear 
global maindir "/path/to/project"
global rawdir "$maindir/rawdata_jfi_fin"
global datdir "$maindir/data_jfi_fin"

// load compustat variables
use "$datdir/compustat_combined_variables_quarterly_aws_3_jfi", clear
	// from 0_1_clean_data/gen_compustat_combined_variables.do
keep gvkey datefq datecq cusip sich fic daterq

// load covenant ratios for all firms
merge 1:m gvkey datefq using "$datdir/compustat_covenant_ratios_quarterly_aws.dta", keep(2 3) nogen
	// from 0_1_clean_data/gen_covenant_variables_annual.do

* use trimmed version of current ratio
drop currentratio
rename currentratio_tr currentratio

* generate standard deviation measures 
gegen sd_ratio = sd(currentratio) if !missing(currentratio), by(covenanttype)
bys gvkey covenanttype (datefq): asrol currentratio, stat(sd) window(datefq -12) gen(sd_ratio_firm)

// merge with covenant level data (only for those with financial covenants)
destring gvkey, replace
merge m:1 gvkey datecq covenanttype using "$datdir/dealscan_combined_panel.dta", keep(1 3) nogen

// generate distance to threshold variable 
gen ratio_diff = (currentratio - effective_thres) / sd_ratio if dir_flag == "Min"
replace ratio_diff = (effective_thres - currentratio) / sd_ratio if dir_flag == "Max" & currentratio > 0
replace ratio_diff = (currentratio - effective_thres) / sd_ratio if dir_flag == "Max" & currentratio < 0

gen ratio_diff_firm = (currentratio - effective_thres) / sd_ratio_firm if dir_flag == "Min"
replace ratio_diff_firm = (effective_thres - currentratio) / sd_ratio_firm if dir_flag == "Max" & currentratio > 0
replace ratio_diff_firm = (currentratio - effective_thres) / sd_ratio_firm if dir_flag == "Max" & currentratio < 0

replace ratio_diff = . if !inrange(ratio_diff, -2, 2)
replace ratio_diff_firm = . if !inrange(ratio_diff_firm, -2, 2)

* tightness at the start of contract
egen id_ = group(gvkey covenanttype)
xtset id_ datefq 

gen ratio_diff_orig = ratio_diff if orig_ind==1 & ratio_diff > 0
replace ratio_diff_orig = l1.ratio_diff if orig_ind==1 & ratio_diff <= 0 & l1.ratio_diff > 0
bys gvkey covenanttype (datefq): carryforward ratio_diff_orig, replace

// keep firms with covenants recorded in DealScan
keep if !missing(effective_thres)

// generate indicator for earnings-based covenants
gen earningscov = 1 if inlist(covenanttype, ///
							  "Max. Debt to EBITDA", ///
							  "Min. Interest Coverage", ///
							  "Min. Fixed Charge Coverage", ///
							  "Min. Debt Service Coverage", ///
							  "Min. Cash Interest Coverage")
replace earningscov = 0 if missing(earningscov)


gen viol = (ratio_diff < 0) 
replace viol = . if missing(ratio_diff)

* number of covenants
bys gvkey datefq: gen ncov = _N

// save distance to threshold (unique id: gvkey datefq)
keep gvkey datefq covenanttype effective_thres currentratio ///
	ratio_diff ratio_diff_firm earningscov orig_ind viol ratio_diff_orig ncov
	
save "$datdir/my_distance_to_threshold_quarterly_new_aws_2.dta", replace



