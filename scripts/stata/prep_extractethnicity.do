** Created 2022-08-31 by Rebecca Joseph, University of Nottingham
*************************************
* Name:	prep_extractethnicity.do
* Creator:	RMJ
* Date:	20220831	
* Desc:	Extracts records from Clinical file by medcode and enttype for ethnicity. 
*		DOES NOT drop if before UTS.
* Notes: Needs frameappend
* Version History:
*	Date	Reference	Update
* 20220831	prep_over65s_extractmedical	New file
* 20230302	prep_extractethnicity	Tidy script
* 20230303	prep_extractethnicity	Update file paths for sharing
*************************************


** NEED TO RUN THIS FROM THE MASTERFILE SO ARGUMENT 'COHORT' IS DEFINED
args cohort
di "`cohort'"

frames reset

if "`cohort'"=="ad" global extract "data/raw/ad"
if "`cohort'"=="over65s" global extract "data/raw/over65s/extract_20220523"

di "`cohort' $extract"

**# list of people eligible for cohort, alongside their UTS date
frame create patlist
frame patlist {
	use "data/prepared/`cohort'/`cohort'_cohortfile.dta"
	keep if eligible==1
	keep patid uts
	sort patid
}

**# list of medcodes
frame create codes
frame codes {
	use "data/prepared/`cohort'/codelists_lookup.dta"
	keep if ethnicity==1
	keep medcode ethnicity_c
	sort medcode
}


**# Extract records from clinical file
frame create import
frame create combine


*** local macro with names of all Clinical files
if "`cohort'"=="ad" {
	local filelist: dir "$extract" files "gold_patid1_Extract_Clinical_*.txt"
}
if "`cohort'"=="over65s" {
	local filelist: dir "$extract" files "medrev_Extract_Clinical_*.txt"
}
di `filelist'


*** Looping over each file: import, keep eligible patients, keep if relevant medcode or enttype, append to main
frame change combine
clear

foreach X of local filelist {
	frame import {
		di "`X'"

		if "`cohort'"=="ad" {
			import delim "$extract/`X'", clear stringcol(1 5 7 10)
		}
		if "`cohort'"=="over65s" {
			import delim "$extract/`X'", clear stringcol(1 5 7 8 14 17)
		}
				
		sort patid
		frlink m:1 patid, frame(patlist)
		count
		keep if patlist<.
		drop patlist
		count

		sort medcode
		frlink m:1 medcode, frame(codes)
		frget *, from(codes)
		
		keep if codes<. | enttype==496 
		drop codes
		count
	}
	frameappend import
}

*** new date variable, and drop if recorded before UTS
sort patid
gen date=date(eventdate,"DMY")
gen date2=date(sysdate,"DMY")
replace date=date2 if date==.
format date %dD/N/CY
drop date2

frlink m:1 patid, frame(patlist)
frget uts, from(patlist)
drop patlist

*** Save
order patid date
sort patid date medcode
save "data/raw/stata/`cohort'_Ethnicity_C.dta", replace

di "`cohort'_Ethnicity_C.dta"

frames reset
exit
