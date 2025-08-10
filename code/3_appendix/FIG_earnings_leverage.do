* Examines how earnings and leverage relate to covenant concern indicators.
* Constructs quantile-based measures and produces appendix figures.

clear
global datdir "/path/to/data"
global outdir "/path/to/output"

* ----------------------------------------------------------------------------
* load data
use  "$datdir/my_combined_variables_quarterly_aws_jfi_check", clear 

// replace altmanz = . if !inrange(altmanz, 0, 5)
// replace altmanz = . if altmanz < 0
replace ratio_diff = . if viol_dsc==1
replace networth_seqq = . if networth < 0
replace booklev = . if booklev > 1

xtset gvkey datefq 

* ------------------------------------------------------------------------------
* generate variables (use full Compustat sample)

loc varlist booklev networth_seqq cashhold size ratio_diff altmanz
foreach var in `varlist' {
	
	cap drop `var'tile
	cap drop `var'_avg `var'_res
	
	gquantiles `var'tile = l1.`var', nq(2) by(sic2 datefq)  xtile
	replace `var'tile = 0 if `var'tile==1
	replace `var'tile = 1 if `var'tile==2
	
}

* invert so bad performance is 1 
loc varlist cashhold size networth_seqq ratio_diff altmanz
foreach var in `varlist' {
	gen tmp = abs(`var'tile-1)
	drop `var'tile
	rename tmp `var'tile
}

// * altmanz 
cap drop loaltmanz
gen loaltmanz = (l1.altmanz<1.81) if inrange(altmanz, 0, 5)

* generate percentiles 
gen query_covfut_pct = query_covfut_any * 100 

* rating indicators
// replace rating_numeric = 99 if missing(rating_numeric)
gen has_rating = inrange(rating_numeric, 1, 22)
gen no_rating = rating_numeric == 99 

* filter sample
keep if sample_flag_any==1

* ------------------------------------------------------------------------------
* binscatter plots

* 1. mentions and earnings surprise
qui binsreg query_covfut_pct ebitda_growth, xline(0, lpattern(dot) lwidth(.5)) ///
	ytitle("CovConcerns (%)") graphregion(color(white)) plotregion(fcolor(white) margin(zero)) nbins(25) ///
	xtitle("Change in earnings (sd)") name("query_sue", replace) 
	
* 2. conditional on leverage
qui binsreg query_covfut_pct ebitda_growth, by(booklevtile) xline(0, lpattern(dot) lwidth(.5)) ///
	ytitle("") graphregion(color(white)) plotregion(fcolor(white) margin(zero)) nbins(25)  ///
	legend(order(1 "Low Leverage" 2 "High Leverage") ring(0) position(1)) ///
	xtitle("Change in earnings (sd)") name("query_lev", replace) nodraw
	
* 3. conditional on networth 
qui binsreg query_covfut_pct ebitda_growth, by(networth_seqqtile) xline(0, lpattern(dot) lwidth(.5)) ///
	ytitle("") graphregion(color(white)) plotregion(fcolor(white) margin(zero)) nbins(25)  ///
	legend(order(1 "High Net Worth" 2 "Low Net Worth") ring(0) position(1)) ///
	xtitle("Change in earnings (sd)") name("query_nw", replace) nodraw
	
* 4. conditional on cash holdings
qui binsreg query_covfut_pct ebitda_growth, by(cashholdtile) xline(0, lpattern(dot) lwidth(.5)) ///
	ytitle("") graphregion(color(white)) plotregion(fcolor(white) margin(zero)) nbins(25)  ///
	legend(order(1 "High Cash" 2 "Low Cash") ring(0) position(1)) ///
	xtitle("Change in earnings (sd)") name("query_cash", replace) nodraw

* 5. conditional on altmanz 
qui binsreg query_covfut_pct ebitda_growth, by(altmanztile) xline(0, lpattern(dot) lwidth(.5)) ///
	ytitle("") graphregion(color(white)) plotregion(fcolor(white) margin(zero)) nbins(25)  ///
	legend(order(1 "High Altman-z" 2 "Low Altman-z") ring(0) position(1)) ///
	xtitle("Change in earnings (sd)") name("query_altman", replace) nodraw
		
* ------------------------------------------------------------------------------	
* export figures 
* default: feb23

graph combine query_sue, ///
	graphregion(color(white)) plotregion(fcolor(white) margin(zero)) name(combine_1, replace) xsize(6in)
graph export "$outdir/query_cov_fut_sue.pdf", as(pdf) replace

graph combine query_lev query_nw query_cash query_altman, row(2) ///
	graphregion(color(white)) plotregion(fcolor(white) margin(zero)) name(combine_2, replace) xsize(8in) ysize(8in) ycommon altshrink 
graph export "$outdir/earnings_leverage.pdf", as(pdf) replace

* for presentation
graph combine query_lev query_nw, row(1) ///
	graphregion(color(white)) plotregion(fcolor(white) margin(zero)) name(combine_2, replace) xsize(8in)  ycommon iscale(1.1)
// graph export "$outdir/earnings_leverage_present.pdf", as(pdf) replace

graph combine query_cash query_altman, row(1) ///
	graphregion(color(white)) plotregion(fcolor(white) margin(zero)) name(combine_2, replace) xsize(8in)  ycommon iscale(1.1)
// graph export "$outdir/earnings_leverage_present_1.pdf", as(pdf) replace
	
