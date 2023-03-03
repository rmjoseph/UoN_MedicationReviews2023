* Created 20 July 2022 by Rebecca Joseph, University of Nottingham
*************************************
* Name:	prep_numdrugsatbaseline.do
* Creator:	RMJ
* Date:	20220720	
* Desc: Use the active prescriptions at index date to count how many different
*		drugs were prescribed
* Notes: 
* Version History:
*	Date	Reference	Update
* 20220720	new file	DRAFT FILE CREATED
* 20220825	prep_numdrugsatbaseline	Add extra category so 1 is grouped alone
* 20220826	prep_numdrugsatbaseline	Keep formulation so counts unique drug/form pairs
* 20230302	prep_numdrugsatbaseline	Tidy script
*************************************

** NEED TO RUN THIS FROM THE MASTERFILE SO ARGUMENT 'COHORT' IS DEFINED
args cohort
di "`cohort'"

frames reset

**# Load datasets
** Get cohort list
frame create cohort
frame change cohort
use patid eligible if eligible==1 using data/prepared/`cohort'/`cohort'_cohortfile.dta
drop eligible

** Load active prescs on index
frame create prescs
frame change prescs
use data/prepared/`cohort'/drugsinwindow_index.dta

** Get prn info
merge m:1 dosekey using data/prepared/`cohort'/clean_dosages.dta, keep(1 3) keepusing(prn) nogen

** Get drugname
merge m:1 prodcode using data/prepared/`cohort'/drugnames_clean.dta, keep(1 3) keepusing(drugnamecode) nogen

keep patid formulation prn drugnamecode
duplicates drop



**# Drop records of non-drugs
drop if formulation==10
duplicates drop



**# Count number of unique drugs (using drugnamecode) separately with/without dropping prn
frame put patid drugnamecode formulation, into(new)
frame new {
	duplicates drop
	bys patid: gen numdrugsbl=_N
	keep patid numdrugsbl
	bys patid: keep if _n==1
}

drop if prn==1
duplicates drop
bys patid: gen numdrugsbl_noprn=_N
keep patid numdrugsbl
bys patid: keep if _n==1


	
**# Merge these two new vars with the cohort list
frame change cohort
frlink m:1 patid, frame(new)
frget numdrugsbl, from(new)
drop new

frlink m:1 patid, frame(prescs)
frget numdrugsbl_noprn, from(prescs)
drop prescs

replace numdrugsbl=0 if numdrugsbl==.
replace numdrugsbl_noprn=0 if numdrugsbl_noprn==.

**# Create categorical polypharmacy var
egen polypharm=cut(numdrugsbl), at(0 1 2 5 10 15 20 25 50) label
egen polypharm_noprn=cut(numdrugsbl_noprn), at(0 1 2 5 10 15 20 25 50) label

**# Tidy and save
label variable numdrugsbl "Number of unique drugs/forms at cohort entry (index)"
label variable numdrugsbl_noprn "Number of unique drugs/forms at index excluding prn prescs"

label variable polypharm "Categorised bl number of unique drugs/forms"
label variable polypharm_noprn "Categorised bl number of unique drugs/forms (excluding prn prescs)"


save data/prepared/`cohort'/numdrugsbaseline.dta, replace


frames reset
exit
