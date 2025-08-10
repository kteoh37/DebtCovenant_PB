* measures of risk from Tarek Hassan's website

clear 
global maindir "/Users/kenteoh/Dropbox/debt_covenant"
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

