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

