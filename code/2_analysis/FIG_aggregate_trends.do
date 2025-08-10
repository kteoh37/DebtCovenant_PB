// Plots aggregate trends of anticipated and confirmed covenant violations over time.
// Utilizes combined quarterly data to construct annual counts for visualization.

clear 
global datdir "/path/to/data"
global outdir "/path/to/output"

**** load quarterly dataset 
use "$datdir/my_combined_variables_quarterly_aws_jfi_check", clear 

* construct measure of subsequent viol
gen subsequent_viol_org = ///
	viol_confirmed_org==1 | f1.viol_confirmed_org==1 | ///
	f2.viol_confirmed_org==1 | f3.viol_confirmed_org==1 | f4.viol_confirmed_org==1 ///
	if !missing(viol_confirmed_org) | !missing(f1.viol_confirmed_org) | ///
	!missing(f2.viol_confirmed_org) | !missing(f3.viol_confirmed_org) | !missing(f4.viol_confirmed_org)
gen subsequent_viol = ///
	cov_viol_ind==1 | f1.cov_viol_ind==1 | f2.cov_viol_ind==1 | f3.cov_viol_ind==1 | f4.cov_viol_ind==1 ///
	if !missing(cov_viol_ind) | !missing(f1.cov_viol_ind) | ///
	!missing(f2.cov_viol_ind) | !missing(f3.cov_viol_ind) | !missing(f4.cov_viol_ind)

* restrict sample
keep if sample_flag_any==1 
keep gvkey datecq subsequent_viol_org query_covfut_any viol_confirmed_org

* collapse to annual level 
gen year = year(dofq(datecq))
gcollapse (max) subsequent_viol_org query_covfut_any viol_confirmed_org, by(gvkey year)

****** generate aggregate indicators
egen anticipate_with_viol = total(query_covfut_any) if subsequent_viol_org==1, by(year)
egen anticipate_no_viol = total(query_covfut_any) if subsequent_viol_org==0, by(year)
egen anticipate_all = total(query_covfut_any) if !missing(subsequent_viol_org), by(year)
egen viol_confirmed1 = total(viol_confirmed_org) if !missing(subsequent_viol_org), by(year)
egen nfirms = count(query_covfut_any) if !missing(subsequent_viol_org), by(year)

gcollapse (max) anticipate_with_viol anticipate_no_viol anticipate_all viol_confirmed1 nfirms, by(year)

loc varlist anticipate_with_viol anticipate_no_viol anticipate_all viol_confirmed1
foreach var in `varlist' {
	gen aux = `var' / nfirms *100
	drop `var'
	rename aux `var'
}

* share of violators with a violation
gen viol_share = anticipate_with_viol / anticipate_all * 100
gen noviol_share = anticipate_no_viol / anticipate_all * 100
gen check_ = viol_share + noviol_share

** plot results (note that these are stacked lines)
gen tmp = 0
twoway ///
    (rarea tmp anticipate_all year if inrange(year, 2002, 2016), ///
    lcolor(blue) fcolor(blue%30) lwidth(vvvthin)) ///
    (rarea tmp anticipate_with_viol year if inrange(year, 2002, 2016), ///
    lcolor(red) fcolor(red%30) lwidth(vvvthin)) ///
    (line anticipate_all year if inrange(year, 2002, 2016), ///
    lcolor(blue) lwidth(medium)) ///
    (line anticipate_with_viol year if inrange(year, 2002, 2016), ///
    lcolor(red) lwidth(medium)) ///
    , plotregion(fcolor(white) margin(zero)) ///
    graphregion(color(white) margin(2 6 2 2)) ///
    bgcolor(white) xtitle("Year") ylab(#5) xlab(#7) ///
    legend(order(3 "CovConcerns, no subseq. violation" 4 "CovConcerns, with subseq. violation") rows(1) pos(6)) ///
    ylab(, grid) ytitle("Share of firms (%)")

graph export "$outdir/anticipation_aggregate_trends.pdf", as(pdf) replace



