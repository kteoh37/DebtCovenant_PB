// generate has_query variable with cusip match 

clear 
global maindir "/path/to/project"
global rawdir "$maindir/rawdata_jfi_fin"
global datdir "$maindir/data_jfi_fin"

// ----------------------------------------------------------------
// read in new query from aws codes (previously 4_2, now 4_3)

import delimited using "$datdir/factset_calls_covenant_mentions_4_3.txt", delimiter("|") stringcols(2 3) clear
keep date repid query_covenant query_cov_fut query_cov_past query_cov_fut_wc query_covenant_wc
rename (query_covenant query_cov_fut query_cov_past) (query_cov query_covfut query_covpas)
rename (query_covenant_wc query_cov_fut_wc) (query_cov_wc query_covfut_wc)

// merge in covmention sentiment score
preserve 
	clear
	import delimited using "$datdir/factset_calls_covenant_mentions_4_2_sentiment.txt", delimiter("|") stringcols(2 3)
	keep date repid cov_senti cov_fut_senti
	
	replace cov_senti = 0 if missing(cov_senti) 
	replace cov_fut_senti = 0 if missing(cov_fut_senti) // set non discussions to zero
	
	rename cov_fut_senti covfut_senti
	
	tempfile sentiment
	save `sentiment'
restore 
merge 1:1 date repid using `sentiment', keep(1 3) nogen
foreach var of varlist cov_senti covfut_senti {
	replace `var' = 0 if missing(`var')
}

// merge in call length 
preserve 
	clear
	import delimited using "$datdir/factset_call_length.txt", delimiter("|") stringcols(2 3)
	keep date repid nwords nsents
	
	rename nwords call_nwords 
	rename nsents call_nsents
	
	tempfile length 
	save `length'
restore
merge 1:1 date repid using `length', keep(1 3) nogen

// merge in Q&A measure
foreach callsec in mda qa {
preserve 
	clear
	import delimited using "$datdir/factset_calls_covenant_mentions_`callsec'_1.txt", delimiter("|") stringcols(2 3)
	keep date repid query_covenant query_cov_fut

	rename query_covenant query_cov_`callsec'
	rename query_cov_fut query_covfut_`callsec'
	
	tempfile mdaqa
	save `mdaqa', replace
restore 
merge 1:1 date repid using `mdaqa', keep(1 3) nogen

}
rename repid report_id



save "$datdir/my_query_variable_aws_org_feb2025.dta", replace
