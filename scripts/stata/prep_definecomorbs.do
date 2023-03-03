** Created 2022-05-23 by Rebecca Joseph, University of Nottingham
*************************************
* Name:	prep_definecomorbs.do
* Creator:	RMJ
* Date:	20220523	
* Desc: Defines vars present/not present at index date (mainly comorbidities)
* Notes: Needs frameappend. Define argument cohort when running file from master script.
* Version History:
*	Date	Reference	Update
* 20220523	new file	create file
* 20220531	prep_definecomorbs	Don't drop dyslipidemia or famhypchol codes
* 20220601	prep_definecomorbs	Add medrev medrev_c sevfrailty_c to drop list
* 20220831	prep_definecomorbs	Change urinaryret to urinarycont
* 20220831	prep_definecomorbs	Add falls fractures to drop list
* 20230302	prep_definecomorbs	Tidy script
*************************************

** NEED TO RUN THIS FROM THE MASTERFILE SO ARGUMENT 'COHORT' IS DEFINED
args cohort
di "`cohort'"


**# Prep
** log
capture log close comorb
local date: display %dCYND date("`c(current_date)'", "DMY")
log using "logs/`cohort'_definecomorbs_`date'.txt", text append name(comorb)

** clear memory
set more off
frames reset





**# Load files
** Load cohort file to get index date and patient list
frame create cohort

frame cohort {
	clear
	use data/prepared/`cohort'/`cohort'_cohortfile.dta
	keep if eligible==1
	keep patid index
	sort patid
}

** Load codelist lookup file
frame create codes

frame codes {
	use data/prepared/`cohort'/codelists_lookup.dta
	sort medcode
}


** Load Clinical, Referral, Test files. Keep date medcode. Append.
frame create load

foreach X of newlist Clinical Referral Test {
	frame load {
		clear
		use patid date medcode using data/raw/stata/`cohort'_`X'
		rename date eventdate
	}
	
	frameappend load
}




**# Combine files and keep records of interest. Create indicator for each var and drop duplicates.
** Combine with patient list
sort patid
frlink m:1 patid, frame(cohort)
keep if cohort<.
frget *, from(cohort)
drop cohort

** Combine with code list file
sort medcode
frlink m:1 medcode, frame(codes)
keep if codes<.
frget *, from(codes)
drop codes

** Drop records recorded AFTER index
order patid index
drop if eventdate > index

** Drop indicators for vars defined elsewhere
drop medrev medrev_c alcohol_c alcohol ethnicity_c ethnicity smoking_c smoking depression_c lipidtests_c lipidtests sevfrailty sevfrailty_c falls fractures

** Drop records with no indicators now
egen keep=rowtotal(anxiety-urinarycont)
tab keep,m
drop if keep==0
drop keep

** Update indicators to show ever present at bl
foreach X of varlist anxiety-urinarycont {
	sort patid `X' eventdate
	by patid: replace `X'=`X'[1]
}

** Keep one record per person
drop index eventdate medcode readcode desc
duplicates drop
duplicates report patid
sort patid




**# Merge this info across to cohort file so have records for everyone
frame change cohort
drop index
frlink 1:1 patid, frame(default)
frget *, from(default)
drop default

** Change variables to binary indicators
recode anxiety-urinarycont (.=0)



**# Save file
save data/prepared/`cohort'/bl_comorbidities.dta, replace



**# Close
frames reset
capture log close comorb
exit
