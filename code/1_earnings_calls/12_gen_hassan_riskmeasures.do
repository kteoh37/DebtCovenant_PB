* Cleans risk measures from Tarek Hassan's dataset and aligns them with gvkey identifiers.
* Converts dates to Stata format and saves a processed file for merging.

clear 
global maindir "/path/to/project"
global rawdir "$maindir/rawdata_jfi_fin"
global datdir "$maindir/data_jfi_fin"

* load data set
use "$rawdir/misc/hassan_riskmeasures"

* keep relevant variables
keep gvkey date_earningscall Risk Sentiment
gen aux = date(date_earningscall, "DMY")
format %td aux
drop date_earningscall 
rename aux call_date

* adjust formatting
destring gvkey, replace 

save "$datdir/hassan_riskmeasures_processed", replace

