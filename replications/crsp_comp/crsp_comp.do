
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

save myDataUS

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
keep fyear sic Book_Leverage1 Book_Leverage2 Mkt_Val_Equity Mkt_Leverage Mkt_Book Asset_Growth Asset_Tangibility Return_Equity Profit_Margin CAPEX_Ratio Div_Yield Div_Payout Total_Payout EBIT_Int_Cov Cash_Holdings Profitability
save "ratios.dta", replace

* Cleaning Ratios 
foreach v of var * { 
	drop if missing(`v') 
}
save "clean_ratios.dta", replace

* Winsorization 
foreach v of var * {
    if "`v'" != "fyear"  & "`v'" != "sic"{
        winsor2 `v', cuts(1 99) by(fyear)
    }
}
keep fyear sic Book_Leverage1_w Book_Leverage2_w Mkt_Val_Equity_w Mkt_Leverage_w Mkt_Book_w Asset_Growth_w Asset_Tangibility_w Return_Equity_w Profit_Margin_w CAPEX_Ratio_w Div_Yield_w Div_Payout_w Total_Payout_w EBIT_Int_Cov_w Cash_Holdings_w Profitability_w
save "w_ratios.dta", replace

* Summary Statistics
drop fyear sic
summarize 
clear

// 1.3 MARKET VALUE OF EQUITY QUARTILES ---------------
use w_ratios
xtile MVE_Q = Mkt_Val_Equity_w, n(4)

sort MVE_Q
by MVE_Q: summarize Mkt_Val_Equity_w

// 1.4 FINANCIAL VS NON-FINANCIAL
gen financial = 1 if sic >= 6000
replace financial = 0 if sice <= 6800

* Verification
















