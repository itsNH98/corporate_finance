
* ###############################################################################################
* #                                                                                             #
* #                                   1 UNDERSTAND DATA                                         #
* #                                                                                             #
* ###############################################################################################

// 1.1 DATA  ---------------

clear
use myData

* Find total ebt market value of assets to find industry leverage 
gen tdmv = (debt_in_cur_liab + lt_debt) / ((share_price * shares_outstanding) + debt_in_cur_liab + lt_debt + preferred_liq_val - def_tax_inv_credit)
summarize tdmv 

* Median industry leverage by fiscal year
bysort sic_code fiscal_year: egen industry_leverage = median(tdmv)

* Tangibility
gen tangibility = property_plant_eq / total_assets

* Market to book
gen mb = ((share_price * shares_outstanding) + debt_in_cur_liab + lt_debt + preferred_liq_val - def_tax_inv_credit) / total_assets

* Profit
gen profit = oper_inc_before_depr / total_assets

* Log Assets 
gen log_assets = log(total_assets)

* Lagged TDMV 
sort gvkey fiscal_year
by gvkey: gen l_tdmv = tdmv[_n-1]

encode dividend_payer, generate(div_flag)
gen div_int = div_flag - 1
drop div_flag dividend_payer

* Cleaning NaN values 
drop if missing(industry_leverage, tangibility , mb, profit, log_assets , div_int , l_tdmv)
save myDataClean, replace

* Visualizations (Exemple)
histogram industry_leverage
clear

* Winsorization
clear
use myDataClean

foreach v of var * {
    if "`v'" == "industry_leverage"  | "`v'" == "tangibility" | "`v'" == "mb" | "`v'" == "profit" | "`v'" == "l_tdmv" | "`v'" == "debt_in_cur_liab" | "`v'" == "lt_debt"{
        winsor2 `v', cuts(0.5 99.5) by(fiscal_year)
    }
}

save winsorizedData, replace

* Visualization 
histogram industry_leverage

// 1.2 DESCRIPTIVE STATISTICS ---------------


* Full Stats
summarize industry_leverage_w debt_in_cur_liab_w lt_debt_w tangibility_w mb_w profit_w l_tdmv_w 


* Before 2003
keep if fiscal_year <= 2003
summarize industry_leverage_w debt_in_cur_liab_w lt_debt_w tangibility_w mb_w profit_w l_tdmv_w 


* After 2003
clear 
use winsorizedData
keep if fiscal_year > 2003
summarize industry_leverage_w debt_in_cur_liab_w lt_debt_w tangibility_w mb_w profit_w l_tdmv_w 


* ###############################################################################################
* #                                                                                             #
* #                                   2 MODELIZATION                                            #
* #                                                                                             #
* ###############################################################################################


// 2.1 LINEAR REGRESSIONS -------------

clear
use winsorizedData

* Simple regression
regress l_tdmv_w industry_leverage_w tangibility_w mb_w profit_w log_assets div_int

* Time FE Effects regressions
reghdfe l_tdmv_w industry_leverage_w tangibility_w mb_w profit_w log_assets div_int, absorb(fiscal_year)

* Full FE Effects regressions
reghdfe l_tdmv_w industry_leverage_w tangibility_w mb_w profit_w log_assets div_int, absorb(gvkey fiscal_year)

* Time and Industry
reghdfe l_tdmv_w industry_leverage_w tangibility_w mb_w profit_w log_assets div_int, absorb(sic_code fiscal_year)

* Clustered 
reghdfe l_tdmv_w industry_leverage_w tangibility_w mb_w profit_w log_assets div_int, noabsorb vce(cluster sic_code fiscal_year)

// 2.2 VOLATILITY

clear
use myFundamentals 

* Cleaning 
foreach v of var * { 
	drop if missing(`v') 
}

* MVA Quarterly Variables
gen mva_quarterly = (cshoq * prccq) + dlcq + dlttq + pstkq - txditcq

* Lagged
sort gvkey datadate
by gvkey: gen l_mva_q = mva_quarterly[_n-1]

* Returns 
gen mva_returns = (mva_quarterly - l_mva_q) / l_mva_q

* Rolling Std
bysort gvkey: asrol mva_returns, stat(sd) win(mva_returns 8) gen(mva_vol)

* Cleaning again
foreach v of var * { 
	drop if missing(`v') 
}

save cleanFundamentals, replace
clear

use cleanFundamentals

* Merging with the mean_vol
merge m:1 gvkey fyearq using "mean_vol.dta"
drop _merge
rename fyearq fiscal_year

save mergedFundamentals, replace



