
* ###############################################################################################
* #                                                                                             #
* #                                   1 UNDERSTAND DATA                                         #
* #                                                                                             #
* ###############################################################################################

// 1.1 DESCRIPTION OF DATA & PLOTTING ---------------


use myData

// Total number of observations 

di "There are " _N " observations in the dataset"

// Only include USA base observations
use myData if loc == "USA"
di "There are " _N " observations in the USA dataset"

save myDataUS, replace

// Plotting number of firms over the years 
clear
use myDataUS
contract gvkey fyear
collapse (count) gvkey, by(fyear)
drop if _n == _N
twoway line gvkey fyear, title("Number of firms per year in USA") xtitle("Year") ytitle("Number of firms") ylabel(6000(1000)12000) 
graph export "plot_nfirms.png", replace

// 1.2  RATIOS, WINSORIZATION & SUMMARY STATISTICS ---------------

// Adding Lagged Variables
clear
use myDataUS

sort gvkey fyear
by gvkey: gen lat = at[_n-1]
by gvkey: gen lprice = prcc_f[_n-1]

// Calculating financial ratios
gen Book_Leverage1 = (dlc + dltt) / at
gen Book_Leverage2 = lt / at
gen Mkt_Val_Equity = csho * prcc_f
gen Mkt_Leverage = (dlc + dltt) / (dlc + dltt + pstk + csho * prcc_f)
gen Mkt_Book = (prcc_f * csho + dltt + dlc + pstkl - txditc) / at
gen Asset_Growth = at / lat - 1
gen Asset_Tangibility = ppent / at
gen Return_Equity = ni / ceq
gen Profit_Margin = ni / sale
gen CAPEX_Ratio = capx / at
gen Div_Yield = (dv / csho) / (lprice / csho)
gen Div_Payout = dv / ni
gen Total_Payout = (dv + prstkc) / ni
gen EBIT_Int_Cov = ebit / xint
gen Cash_Holdings = che / at
gen Profitability = oibdp / at

* Create a new dataset (table) called "ratios"
keep fyear gvkey sic Book_Leverage1 Book_Leverage2 Mkt_Val_Equity Mkt_Leverage Mkt_Book Asset_Growth Asset_Tangibility Return_Equity Profit_Margin CAPEX_Ratio Div_Yield Div_Payout Total_Payout EBIT_Int_Cov Cash_Holdings Profitability
save "ratios.dta", replace

* Cleaning Ratios 
foreach v of var * { 
	drop if missing(`v') 
}
save "clean_ratios.dta", replace

* Winsorization 
foreach v of var * {
    if "`v'" != "fyear"  & "`v'" != "sic" & "`v'" != "gvkey"{
        winsor2 `v', cuts(1 99) by(fyear)
    }
}
keep fyear sic gvkey Book_Leverage1_w Book_Leverage2_w Mkt_Val_Equity_w Mkt_Leverage_w Mkt_Book_w Asset_Growth_w Asset_Tangibility_w Return_Equity_w Profit_Margin_w CAPEX_Ratio_w Div_Yield_w Div_Payout_w Total_Payout_w EBIT_Int_Cov_w Cash_Holdings_w Profitability_w
save "w_ratios.dta", replace

* Summary Statistics
drop fyear sic gvkey
summarize 
clear

// 1.3 MARKET VALUE OF EQUITY QUARTILES ---------------
use w_ratios
xtile MVE_Q = Mkt_Val_Equity_w, n(4)

sort MVE_Q
by MVE_Q: summarize Mkt_Val_Equity_w

// 1.4 INDUSTRY GROUPS
* Financial 
gen financial = 1 if sic >= 6000
replace financial = 0 if sic < 6800

* Utility
gen utility = 1 if sic >= 4000
replace utility = 0 if sic < 5000

tabulate(financial)
tabulate(utility)

* Summary Statistics 
summarize Book_Leverage1_w Book_Leverage2_w Mkt_Leverage_w if financial == 1 
summarize Book_Leverage1_w Book_Leverage2_w Mkt_Leverage_w if utility == 1 
summarize Book_Leverage1_w Book_Leverage2_w Mkt_Leverage_w if financial == 0 & utility == 0

keep if financial == 0 & utility ==0
drop sic MVE_Q financial utility
save "industry_filtered_ratios.dta", replace


* ###############################################################################################
* #                                                                                             #
* #                                   	  2 EDA                                        			#
* #                                                                                             #
* ###############################################################################################

clear
use industry_filtered_ratios

// 2.1 Scatter matrix, weighted ratio progression ------------

* drop fyear
* graph matrix _all 

* Rolling weighted average of the ratios
ds fyear gvkey, not
collapse (mean) `r(varlist)', by(fyear)

* Example Graph
twoway line Book_Leverage1_w fyear

// 2.3 Correlation Matrix for main variables 
clear
use industry_filtered_ratios
pwcorr Book_Leverage1_w EBIT_Int_Cov_w Cash_Holdings_w Profitability_w Total_Payout_w Mkt_Book_w


// 2.4 Linear Models ------------

// A. Simple Model
/*
Following model : y_it = a + BX_it + e_it 
y: Book leverage 
x: Profitability
*/

* Robust Regression
regress Book_Leverage1_w Profitability_w , robust

// B. Fixed Effects model
reghdfe Book_Leverage1_w  Profitability_w, absorb(gvkey fyear)

// C. Firm by Firm (> 10) regression 
sort gvkey
by gvkey: egen gvkey_count = count(gvkey)
keep if gvkey_count > 10 
drop gvkey_count 
save "gvkey_above10.dta", replace

clear 
use gvkey_above10

* Raw regressions
bysort gvkey: regress Book_Leverage1_w Profitability_w

* Coefficients
statsby, by(gvkey): regress Book_Leverage1_w Profitability_w
save "coeffs.dta", replace

// D. Summary Stats and Histograms 
histogram _b_Profitability_w 
summarize _b_Profitability_w 

* Quartile cut by Market Value 
clear 
use industry_filtered_ratios
xtile MVE_Q = Mkt_Val_Equity_w, n(4)
sort gvkey
by gvkey: gen dup = cond(_N==1, 0 , _n)
sort gvkey
by gvkey: egen max_target = max(dup)
keep if dup == max_target 
keep gvkey MVE_Q
save "gvkey_quartiles.dta", replace


* Merged betas and quartiles 
clear 
use coeffs
merge 1:1 gvkey using "gvkey_quartiles.dta"
save "coeffs_quartiles.dta", replace

* Summarize 
summarize _b_Profitability_w if MVE_Q == 1
by MVE_Q: summarize _b_Profitability_w 


* ###############################################################################################
* #                                                                                             #
* #                             		3 BANKRUPTCIES                                        	#
* #                                                                                             #
* ###############################################################################################

// 3.1 Enron and GE ------------

* gvkey are 5073 and 6127 for GE and ENRON
use ratios 
keep if gvkey == 5073
save "ge.dta", replace 
clear 
use ratios 
keep if gvkey == 6127
save "enron.dta"
clear 

// 3.2 Standard deviations 
use w_ratios
sort gvkey
by gvkey: egen gvkey_count = count(gvkey)
keep if gvkey_count > 5

// Create a new variable 'Industry' to hold the classification
gen Industry = "None"

// Classify the values based on the SIC ranges using generate and replace
replace Industry = "Agriculture_Forestry_Fishing" if inrange(sic, 0100.0, 0999.0)
replace Industry = "Mining" if inrange(sic, 1000.0, 1499.0)
replace Industry = "Construction" if inrange(sic, 1500.0, 1799.0)
replace Industry = "Manufacturing" if inrange(sic, 2000.0, 3999.0)
replace Industry = "Transport_PublicUtilities" if inrange(sic, 4000.0, 4999.0)
replace Industry = "Wholesale" if inrange(sic, 5000.0, 5199.0)
replace Industry = "Retail" if inrange(sic, 5200.0, 5999.0)
replace Industry = "Finance_Insurance_RE" if inrange(sic, 6000.0, 6799.0)
replace Industry = "Services" if inrange(sic, 7000.0, 8999.0)


ds fyear gvkey sic gvkey_count Industry, not
collapse (sd) `r(varlist)', by(gvkey Industry)
save "std_industries.dta", replace

drop gvkey 
sort Industry
by Industry: summarize 

// And we're done ! 





































