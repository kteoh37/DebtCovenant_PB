// Adjust employment specification table for export
clear 
global datdir "/path/to/data"
global outdir "/path/to/output"

** adjust stacked (main) or interact (appendix) file
loc file "emp_may2025" 

***** investment policy
loc i = 1
	
* adjust formatting	
filefilter "$outdir/regression_violation_`i'_`file'.tex" "$outdir/regression_violation_`i'_`file'_adj0.tex", ///
	from( ///
	"&        ." ///
	) to( ///
	"&        " ///
	) ///
	replace

* add open header
filefilter "$outdir/regression_violation_`i'_`file'_adj0.tex" "$outdir/regression_violation_`i'_`file'_adj1.tex", ///
	from( ///
"                &\BSmulticolumn{1}{c}{(1)}&\BSmulticolumn{1}{c}{(2)}&\BSmulticolumn{1}{c}{(3)}&\BSmulticolumn{1}{c}{(4)}&\BSmulticolumn{1}{c}{(5)}\BS\BS" ///
	) to( ///
	"{\BSdef\BSsym#1{\BSifmmode^{#1}\BSelse\BS(^{#1}\BS)\BSfi}\n\BSbegin{tabular}{l*{5}{c}}\n\BStoprule \n                &\BSmulticolumn{1}{c}{(1)}&\BSmulticolumn{1}{c}{(2)}&\BSmulticolumn{1}{c}{(3)}&\BSmulticolumn{1}{c}{(4)}&\BSmulticolumn{1}{c}{(5)}\BS\BS" /// 
	) ///
	replace

* add open header
filefilter "$outdir/regression_violation_`i'_`file'_adj1.tex" "$outdir/regression_violation_`i'_`file'_adj2.tex", ///
	from( ///
	"\BShline" ///
	) to( ///
	"" /// 
	) ///
	replace	
	
* add table close
* Open the LaTeX file for writing
file open myfile using "$outdir/regression_violation_`i'_`file'_adj2.tex", write append
file write myfile "Covenant Controls&\checkmark   &\checkmark   &\checkmark   &\checkmark  &\checkmark   \\"_n
file write myfile "Industry \& Time FE &\checkmark   &\checkmark   &\checkmark   &\checkmark   &\checkmark   \\"_n
file write myfile "\bottomrule" _n
file write myfile "\end{tabular}" _n
file write myfile "}" _n
file close myfile	

erase "$outdir/regression_violation_`i'_`file'.tex"
erase "$outdir/regression_violation_`i'_`file'_adj0.tex"
erase "$outdir/regression_violation_`i'_`file'_adj1.tex"
shell mv "$outdir/regression_violation_`i'_`file'_adj2.tex" "$outdir/regression_violation_`i'_`file'.tex"
