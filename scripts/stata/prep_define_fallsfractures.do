** Created 2022-08-31 by Rebecca Joseph, University of Nottingham
*************************************
* Name:	prep_define_fallsfractures.do
* Creator:	RMJ
* Date:	20220831	
* Desc: Indicator of a fall or fracture in the year (365days) on or before index
* Notes: Needs frameappend. Define argument cohort when running file from master script.
* Version History:
*	Date	Reference	Update
* 20220831	prep_definecomorbs	Create file
*************************************

** NEED TO RUN THIS FROM THE MASTERFILE SO ARGUMENT 'COHORT' IS DEFINED
args cohort
di "`cohort'"

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
	keep if falls==1|fractures==1
	keep medcode falls fractures
}


** Load Clinical, Referral, Test files. Keep date medcode. Append.
frame create load
foreach X of newlist Clinical Referral Test {
	frame load {
		clear
		use patid date medcode using data/raw/stata/`cohort'_`X'
		rename date eventdate
		frlink m:1 medcode, frame(codes)
		keep if codes<.
		frget falls fractures, from(codes)
		drop codes
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

** Drop events recorded AFTER index
order patid index
drop if eventdate > index

** Drop events recorded more than one year BEFORE index
keep if eventdate >= (index-365) 


** Update indicators to show ever present at bl
foreach X of varlist falls fractures {
	sort patid `X' eventdate
	by patid: replace `X'=`X'[1]
}

** Drop duplicates
keep patid falls fractures
duplicates drop
duplicates report patid



**# Merge this info across to cohort file so have records for everyone
frame change cohort
drop index
frlink 1:1 patid, frame(default)
frget *, from(default)
drop default

** Change variables to binary indicators
recode falls fractures (.=0)

**# Save file
save data/prepared/`cohort'/bl_fallsfractures.dta, replace

**# Close
frames reset
exit
