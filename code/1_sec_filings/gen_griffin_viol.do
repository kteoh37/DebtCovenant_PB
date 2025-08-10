// analyze griffin's violation data

clear 
global maindir "/path/to/project"
global rawdir "$maindir/rawdata_jfi_fin"
global datdir "$maindir/data_jfi_fin"

* read in Griffin's violation data
import delimited using "$rawdir/misc/griffin_violdata", varnames(1)

* format date variable
loc varlist datadate fdate 
foreach var in `varlist' {
	gen tmp = date(`var',"YMD")
	format %td tmp
	drop `var'
	rename tmp `var'
}

keep gvkey datadate fdate viol_confirmed
save "$datdir/griffin_violdata", replace
