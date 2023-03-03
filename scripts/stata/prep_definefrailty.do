** Created 2022-06-01 by Rebecca Joseph, University of Nottingham
*************************************
* Name:	prep_definefrailty.do
* Creator:	RMJ
* Date:	20220601	
* Desc:	Defines frailty based on coded records.
* Notes: frameappend. Define arg 'cohort'.
* Version History:
*	Date	Reference	Update
* 20220601	new file	Create file
* 20230302	prep_definefrailty	Clean script
*************************************

** NEED TO RUN THIS FROM THE MASTERFILE SO ARGUMENT 'COHORT' IS DEFINED
args cohort
di "`cohort'"


** Log
local date: display %dCYND date("`c(current_date)'", "DMY")
di `date'
local logname: display "prep_frailty_`cohort'_"`date'
di "`logname'"

capture log close frail
log using "logs/`logname'.log", append name(frail)

** frames reset
frames reset
set more off

*****************************************
**# Define frailty using directly coded info (Read code, frailty scores)
***# Cohort file
capture frame create cohort
frame cohort {
	clear
	use data/prepared/`cohort'/`cohort'_cohortfile.dta
	keep if eligible==1
	keep patid index
	sort patid
}

***# Frailty code lists
capture frame create codes
frame codes {
	clear
	use medcode sevfrail* if sevfrailty==1 using data/prepared/`cohort'/codelists_lookup.dta
	sort medcode
	keep medcode sevfrailty_c
}

***# Records in additional file
capture frame create addit
frame addit {
	clear
	use patid adid enttype data1 if enttype==372 using data/raw/stata/`cohort'_Additional.dta
	destring data1, replace
	sort patid adid
	drop enttype
}

***# Coded records
use patid date medcode adid enttype using data/raw/stata/`cohort'_Clinical.dta
sort medcode
frlink m:1 medcode, frame(codes)
keep if codes<.
frget *, from(codes)

capture frame create load
foreach X of newlist Referral Test {
	frame load {
		clear
		use patid date medcode using data/raw/stata/`cohort'_`X'.dta
		sort medcode
		frlink m:1 medcode, frame(codes)
		keep if codes<.
		frget *, from(codes)
		
		count
	}
	
	if `r(N)'!=0 {
		frameappend load
	}

}

***# Combine clinical records and additional file records
sort patid adid
frlink m:1 patid adid, frame(addit)
frget *, from(addit)

***# Severe frailty read code
gen frailtyrec=1 if sevfrailty_c=="severe"

***# Clinical Frailty Scale: range 1-9, cfs>=7 is severe
drop if sevfrailty_c=="cfs" & (data1==0 | data1>9)
replace frailtyrec=1 if sevfrailty_c=="cfs" & data1>=7

***# eFI: range 0-1, efi>0.36 is severe
drop if sevfrailty_c=="efi" & (data1<0 | data1>1)
replace frailtyrec=1 if sevfrailty_c=="efi" & data1>0.36

***# Keep records of severe frailty on/before index
keep if frailtyrec==1
frlink m:1 patid, frame(cohort)
frget index, from(cohort)
drop if date>index

keep patid frailtyrec
duplicates drop

***# link back to cohort file
frame change cohort
frlink 1:1 patid, frame(default)
frget *, from(default)
keep patid frailtyrec
replace frailtyrec=0 if frailtyrec==.
label var frailtyrec "Indicates a Read code or frailty score for severe frailty "



save data/prepared/`cohort'/bl_frailty.dta, replace

*****************************************
frames reset
capture log close frail
exit
