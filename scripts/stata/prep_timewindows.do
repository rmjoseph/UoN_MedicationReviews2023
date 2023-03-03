** Created 2022-06-02 by Rebecca Joseph, University of Nottingham
*************************************
* Name:	prep_timewindows.do
* Creator:	RMJ
* Date:	20220602	
* Desc:	Time window start and stop dates
* Notes: frameappend. Define arg 'cohort'.
* Version History:
*	Date	Reference	Update
* 20220602	new file	Create file
* 20220721	prep_timewindows	error fix: elig6 used r_plus4
* 20221003	prep_timewindows	Define vars r_minus1 and elig1
* 20221003	prep_timewindows	Use floor() to round dates to integers
* 20230302	prep_timewindows	Tidy script
*************************************

** NEED TO RUN THIS FROM THE MASTERFILE SO ARGUMENT 'COHORT' IS DEFINED
args cohort
di "`cohort'"


** Log
local date: display %dCYND date("`c(current_date)'", "DMY")
di `date'
local logname: display "prep_timewindows_`cohort'_"`date'
di "`logname'"

capture log close windows
log using "logs/`logname'.log", append name(windows)

** frames reset
frames reset
set more off

*****************************************
** Need: eligibility flag, medication reviews flag, medication reviews date, follow-up date
use patid index eligible cprdend if eligible==1 using data/prepared/`cohort'/`cohort'_cohortfile.dta

merge 1:1 patid using data/prepared/`cohort'/medicationreviews, keepusing(medreview medreview_s firstrev_date firstrev_date_s)
drop _merge

keep if medreview==1


**# Sensitivity analysis definition
frame put if medreview_s==1, into(sens)
frame sens {
	
	drop medreview firstrev_date
	
	gen r_minus3 = floor(firstrev_date - (3*365.25/12))
	gen r_minus6 = floor(firstrev_date - (6*365.25/12))
	gen r_minus1 = floor(firstrev_date - (1*365.25/12))
	gen r_plus3 = floor(firstrev_date + (3*365.25/12))
	gen r_plus6 = floor(firstrev_date + (6*365.25/12))
	gen r_plus1 = floor(firstrev_date + (1*365.25/12))
	gen r_plus4 = floor(firstrev_date + (4*365.25/12))
	format r_* %dD/N/CY

	gen elig3 = r_plus3 <= cprdend
	gen elig4 = r_plus4 <= cprdend
	gen elig6 = r_plus4 <= cprdend
	gen elig1 = r_plus1 <= cprdend
	
	rename firstrev_date review
	
	keep patid r* elig*
	
	save data/prepared/`cohort'/timewindows_Q2_s.dta, replace

}


**# Main definition
count if firstrev_date==index

gen r_minus3 = floor(firstrev_date - (3*365.25/12))
gen r_minus6 = floor(firstrev_date - (6*365.25/12))
gen r_minus1 = floor(firstrev_date - (1*365.25/12))
gen r_plus3 = floor(firstrev_date + (3*365.25/12))
gen r_plus6 = floor(firstrev_date + (6*365.25/12))
gen r_plus1 = floor(firstrev_date + (1*365.25/12))
gen r_plus4 = floor(firstrev_date + (4*365.25/12))
format r_* %dD/N/CY

gen elig3 = r_plus3 <= cprdend
gen elig4 = r_plus4 <= cprdend
gen elig6 = r_plus6 <= cprdend
gen elig1 = r_plus1 <= cprdend

rename firstrev_date review

keep patid r* elig*

save data/prepared/`cohort'/timewindows_Q2.dta, replace




*****************************************
frames reset
capture log close windows
exit
