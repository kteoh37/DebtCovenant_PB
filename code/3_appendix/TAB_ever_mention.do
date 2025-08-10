** Computes the share of firms that mention covenants or experience violations in earnings calls.
** Summarizes results across ratings, size, and industry subsamples.

clear 
global datdir "/path/to/data"
global outdir "/path/to/output"

* load data
use "$datdir/my_combined_variables_quarterly_aws_jfi_check", clear 

* update text based measure of covenant violations
// replace rating_numeric = 99 if missing(rating_numeric) // treat missing as unrated
gen has_rating = inrange(rating_numeric, 1, 22)
gen has_rating_1 = .
replace has_rating_1 = 1 if rating_ig==1
replace has_rating_1 = 2 if rating_hy==1
replace has_rating_1 = 3 if has_rating==0

* size quantiles
xtset gvkey datefq
gquantiles sizetile = l1.size, by(datefq) nq(5) xtile 

gen airlines = sic2==45

* keep relevant sample
keep if sample_flag_any==1

* compute fraction of firms ever mentioning covenants in earnings calls
cap drop ever*
gegen ever_mention = max(query_cov_any), by(gvkey)
gegen ever_mention_fut = max(query_covfut_any), by(gvkey)
gegen ever_viol = max(viol_confirmed_org), by(gvkey)



* -----------------------------------------------------------------
* full sample 

preserve 
	
	gcollapse (mean) ever_mention ever_mention_fut ever_viol, by(gvkey)

	matrix outmat = J(1,3,.)
	qui sum ever_mention_fut 
	mat outmat[1,1] = `r(mean)'
	qui sum ever_viol 
	mat outmat[1,2] = `r(mean)'
	mat outmat[1,3] = outmat[1,1]-outmat[1,2]

	mat coln outmat = "Any Concern" "Any Violation" "Difference"
	mat rown outmat = "All firms"
		
// 	esttab matrix(outmat, fmt(2 2 2)), 	///
// 		booktabs nomtit

	* table for paper
	esttab matrix(outmat, fmt(2 2 2)) using "$outdir/ever_mention_share.tex", replace nomtitle ///
		booktabs
		
	* table for presentation
	esttab matrix(outmat, fmt(2 2 2)) using "$outdir/ever_mention_share_present.tex", replace nomtitle ///
		booktabs	
		
restore 
		
* -----------------------------------------------------------------
* average concerns and violations by industry

matrix outmat = J(10, 3, .)	

preserve 

	gcollapse (mean) ever_mention ever_mention_fut ever_viol (max) ff_ind_12, by(gvkey)
	
	loc j = 0

	forval i = 1/12 {
		
		
		if (`i'!=11)&(`i'!=12) {
			
			loc ++j
			di `j'
			* concerns
			qui sum ever_mention_fut if ff_ind_12==`i'
			mat outmat[`j',1]= `r(mean)'
			
			* violations
			qui sum ever_viol if ff_ind_12==`i'
			mat outmat[`j',2] = `r(mean)'
			
			* test equality of means
			mat outmat[`j',3] = outmat[`j',1]-outmat[`j',2]
// 			qui ttest ever_mention_fut==ever_viol if ff_ind_12==`i'
// 			mat outmat[`j',5] = r(t)
			
		}
		

	}	
	
	mat coln outmat = "Mention" "Violation" "Difference"
	mat rown outmat = "  Non-Durables" "Durables" "Manufacturing" "Energy" "Chemicals" ///
	 "Business-Equipment" "Telecom" "Utilities" "Retail" "Health"

	clear
	svmat2 outmat, names(col) r(row) full
	gsort -Mention
	ds row, not
	mkmat `r(varlist)', rownames(row) mat("A_sorted")
	
restore


esttab matrix(A_sorted, fmt(2 2 2)), replace nomtitle 
 
esttab matrix(A_sorted, fmt(2 2 2)) using "$outdir/ever_mention_share.tex", append nomtitle ///
	posthead("\addlinespace \addlinespace  \textit{A. By industry} & & & \\ \addlinespace") booktabs ///
	collabels(,none)


* covenant concerns and size 
preserve 
	
	gcollapse (mean) ever_mention ever_mention_fut ever_viol size (count) datefq (max) sizetile has_rating, by(gvkey)
	
	matrix outmat = J(5, 3, .)
	
	* conditional 
	loc j = 0
	forval i = 1/5 {
			
			loc ++j
			di `j'
			* concerns
			qui sum ever_mention_fut if sizetile==`i'
			mat outmat[`j',1]= `r(mean)'
			
			* violations
			qui sum ever_viol if sizetile==`i'
			mat outmat[`j',2] = `r(mean)'
			
			* test equality of means
			mat outmat[`j',3] = outmat[`j',1]-outmat[`j',2]
			
	}	
	
	
// 	graph bar ever_mention_fut ever_viol, over(margintile)
	
restore


mat coln outmat = "Mention" "Violation" "Mention-Violation"
mat rown outmat = "1 (small)" "2" "3" "4" "5 (large)"
esttab matrix(outmat, fmt(2 2 2)), replace nomtitle 

* table for paper
esttab matrix(outmat, fmt(2 2 2)) using "$outdir/ever_mention_share.tex", append nomtitle ///
	posthead("\addlinespace \addlinespace \textit{B. By book asset quintile} & & & \\ \addlinespace") booktabs ///
	collabels(,none)

* table for presentation
esttab matrix(outmat, fmt(2 2 2)) using "$outdir/ever_mention_share_present.tex", append nomtitle ///
	posthead("\addlinespace \addlinespace \textit{A. By book asset quintile} & & & \\ \addlinespace") booktabs ///
	collabels(,none)
	
* covenant concerns and credit ratings
preserve 
	
	gcollapse (mean) ever_mention ever_mention_fut ever_viol (count) datefq (max) has_rating_1, by(gvkey)
	
	matrix outmat = J(3, 3, .)
	
	
	* conditional 
	loc j = 0
	forval i = 1/3 {
			
			loc ++j
			di `j'
			* concerns
			qui sum ever_mention_fut if has_rating_1==`i'
			mat outmat[`j',1]= `r(mean)'
			
			* violations
			qui sum ever_viol if has_rating_1==`i'
			mat outmat[`j',2] = `r(mean)'
			
			* test equality of means
			mat outmat[`j',3] = outmat[`j',1]-outmat[`j',2]
			
	}	
	
	
restore


mat coln outmat = "Mention" "Violation" "Mention-Violation"
mat rown outmat = "Investment Grade" "High Yield" "No rating"
esttab matrix(outmat, fmt(2 2 2)), replace nomtitle 

esttab matrix(outmat, fmt(2 2 2)), append nomtitle ///
	posthead("\addlinespace \addlinespace \textit{C. By S&P credit rating} & & & \\ \addlinespace") booktabs ///
	collabels(,none)

* table for paper 
esttab matrix(outmat, fmt(2 2 2)) using "$outdir/ever_mention_share.tex", append nomtitle ///
	posthead("\addlinespace \addlinespace \textit{C. By S\&P credit rating} & & & \\ \addlinespace") booktabs ///
	collabels(,none)
	
* table for presentation	
esttab matrix(outmat, fmt(2 2 2)) using "$outdir/ever_mention_share_present.tex", append nomtitle ///
	posthead("\addlinespace \addlinespace \textit{B. By S\&P credit rating} & & & \\ \addlinespace") booktabs ///
	collabels(,none)
	
* edit file to remove unnecessary lines
* table for paper
filefilter "$outdir/ever_mention_share.tex" "$outdir/ever_mention_share1.tex", ///
	from( ///
	"\BSbottomrule\n\BSend{tabular}\n\BSbegin{tabular}{l*{3}{c}}\n\BStoprule" ///
	) to("") replace

* table for presentation
filefilter "$outdir/ever_mention_share_present.tex" "$outdir/ever_mention_share1_present.tex", ///
	from( ///
	"\BSbottomrule\n\BSend{tabular}\n\BSbegin{tabular}{l*{3}{c}}\n\BStoprule" ///
	) to("") replace
	
erase "$outdir/ever_mention_share.tex"
erase "$outdir/ever_mention_share_present.tex"


