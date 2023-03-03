** Created 01 Sept 2022 by Rebecca Joseph, University of Nottingham
*************************************
* Name:	prep_defineethnicity_v2.do
* Creator:	RMJ
* Date:	20220901	
* Desc: Defines ethnicity wrt index date (allows records pre uts)
* Notes: Needs frameappend. Define argument cohort when running file from master script.
* Version History:
*	Date	Reference	Update
* 20220901	prep_defineethnicity	update version using updated extract
*************************************

** NEED TO RUN THIS FROM THE MASTERFILE SO ARGUMENT 'COHORT' IS DEFINED
args cohort
di "`cohort'"

frames reset
set more off


**# Load cohort file, get index date and patient list
frame create cohort
frame cohort {
	clear
	use data/prepared/`cohort'/`cohort'_cohortfile.dta
	keep if eligible==1
	keep patid index
	sort patid
}

**# Load ethnicity code list
frame create codelist
frame codelist {
	use "data/prepared/`cohort'/codelists_lookup.dta"
	keep medcode ethnicity*
	keep if ethnicity==1
	sort medcode
}

**# Load ethnicity extract
clear
use patid medcode date enttype ethnicity_c using "data/raw/stata/`cohort'_Ethnicity_C.dta"
rename date eventdate
frlink m:1 medcode, frame(codelist)
keep if codelist<.
drop codelist
count

**# Combine ethnicity records with patient list
sort patid
frlink m:1 patid, frame(cohort)
keep if cohort<.
frget *, from(cohort)
drop cohort

**# Get ethnicity categories
drop ethnicity_c
frlink m:1 medcode, frame(codelist)
frget *, from(codelist)
drop codelist ethnicity
drop medcode

**# Indicator of whether people had multiple categories recorded
bys patid ethnicity_c: gen count=1 if _n==1
bys patid: egen multipleeethnicity=sum(count)
replace multiple=(multiple>1)

**# If multiple categories recorded, keep the most recent
sort patid eventdate ethnicity_c
by patid: keep if _n==_N
duplicates report patid

**# For remaining, keep single record
keep patid ethnicity_c
duplicates drop

**# Combine with the patient list 
frame change cohort
frlink 1:1 patid, frame(default)
frget *, from(default)
drop default
tab ethnicity,m

**# Save file
rename ethnicity_c ethnicity
label variable ethnicity "Patient ethnicity (missing if not recorded)"
save data/prepared/`cohort'/ethnicity.dta, replace

***
frames reset
exit
