
* ###############################################################################################
* #                                                                                             #
* #                                   1 EMPIRICAL EXERCISE                                      #
* #                                                                                             #
* ###############################################################################################

// 1.1 Data  ---------------

// cd "~/Mirror/Work/research/main/corporate_finance/replications/becker_stromberg"

// import delimited "./annually.csv"
// save annualData, replace
// clear
//
// import delimited "./quarterly.csv"
// save quarterlyData, replace
// clear

// 1.2 Annual data preparation
use annualData
drop if missing(incorp)
drop if sic >= 6000 & sic <= 6999
drop if sic >= 4900 & sic <= 4999

sort gvkey 
by gvkey: gen lagged_at = at[_n-1]

gen roa = ebitda / lagged_at
gen ros = ebitda / sale

* Calculate changes using bysort and generate new variables
bysort gvkey: gen ceq_change = ceq - ceq[_n-1]
bysort gvkey: gen txdb_change = txdb - txdb[_n-1]
bysort gvkey: gen re_change = re - re[_n-1]

* Calculate equity_issue
gen equity_issue = ceq_change + txdb_change - re_change

* Calculate equity_issue_assets
gen equity_issue_assets = (ceq_change + txdb_change - re_change) / lagged_at

* Winsorization of the equity_issue_assets variable 
foreach v of var * {
    if "`v'" == "equity_issue_assets" {
        winsor2 `v', cuts(1 99) 
    }
}

gen log_assets = ln(at)
gen leverage = (at - ceq - txdb) / at

save annualFinal, replace

clear

// 1.3 Quarterly data preparation
use quarterlyData
drop if missing(incorp)
drop if sic >= 6000 & sic <= 6999
drop if sic >= 4900 & sic <= 4999

* Calculation of certain financial ratios 
gen ebitda_q = saleq - cogsq - xsgaq
bysort gvkey: gen lagged_atq = atq[_n-1]
gen roa = ebitda_q / lagged_atq
bysort gvkey: gen ch_roa = roa - roa[_n-1]

* Volatility of ROA 
bysort gvkey: asrol ch_roa, stat(sd) win(ch_roa 8) gen(vol_roa)
replace vol_roa = vol_roa * sqrt(4)
keep if fqtr == 4
save quarterlyFinal, replace
clear

// 1.4 Data merging 
use quarterlyFinal
keep gvkey fyearq vol_roa
rename fyearq fyear
save quarterlyToMerge, replace
clear

use annualFinal 
merge m:1 fyear gvkey using "quarterlyToMerge.dta"

foreach v of var * { 
	drop if missing(`v') 
}

// 1.5 Indicator variables 
gen DE = (incorp== "DE")
gen post_rule = (fyear >= 1992)
gen pre_rule = (fyear < 1992)

* Multiple conditions for different state (exemple)
count if DE == 1 & post_rule == 1

* Descriptive Statistics for various cases (exemple)
summarize roa if DE == 1 & post_rule == 1

* DnD equations
regress roa i.DE##i.post_rule
regress ros i.DE##i.post_rule

















