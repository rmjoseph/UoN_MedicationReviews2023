** Created 2022-05-27 by Rebecca Joseph, University of Nottingham
*************************************
* Name:	prep_over65s_extractmedical.do
* Creator:	RMJ
* Date:	20220527	
* Desc:	Extracts records by medcode from Clinical, Test, Referral, Immunisation for
*		over65s cohorts. Keeps for eligible pats. Drops records before uts.
* Notes: Needs frameappend
* Version History:
*	Date	Reference	Update
* 20220527	new file	create file
* 20220530	prep_over65s_extractmedical	Import id vars as strings
* 20220531	prep_over65s_extractmedical	Add the additional lipid enttypes
* 20220601	prep_over65s_extractmedical	bug fix: add 'keep if codes<.' back in
* 20230302	prep_over65s_extractmedical	Tidy script
*************************************

** log
capture log close extract
local date: display %dCYND date("`c(current_date)'", "DMY")
log using "logs/over65s_extract_medical_`date'.txt", text append name(extract)

** data directory macro
global extract "data/raw/over65s/extract_20220523"

** clear memory
set more off
frames reset

*************************************

**# list of people eligible for cohort, alongside their UTS date
frame create patlist
frame patlist {
	use data/prepared/over65s/over65s_cohortfile.dta
	keep if eligible==1
	keep patid uts
	sort patid
}

**# list of medcodes
frame create codes
frame codes {
	use data/prepared/over65s/codelists_lookup.dta
	keep medcode
	sort medcode
}

**# Extract records from clinical file
frame create import
frame create combine

*** local macro with names of all Clinical files
local filelist: dir "$extract" files "medrev_Extract_Clinical_*.txt"
di `filelist'

*** Looping over each file: import, keep eligible patients, keep if relevant medcode or enttype, append to main
frame change combine
clear

foreach X of local filelist {
	frame import {
		di "`X'"
		import delim "$extract/`X'", clear stringcols(1 5 7 8 14 17)
		sort patid
		frlink m:1 patid, frame(patlist)
		count
		keep if patlist<.
		drop patlist
		count
		sort medcode
		frlink m:1 medcode, frame(codes)
		keep if codes<. | enttype==4 | enttype==13 | enttype==14 | enttype==23 | enttype==163 ///
			| enttype==175 |enttype==177 | enttype==202 | enttype==206 |  enttype==214 ///
			| enttype==363 |  enttype==461 
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

count
drop if date<uts
count

*** Save
order patid date
sort patid date medcode
save data/raw/stata/over65s_Clinical.dta, replace



**# Extract records from test file
*** local macro with names of all Test files
local filelist: dir "$extract" files "medrev_Extract_Test_*.txt"
di `filelist'

*** Looping over each file: import, keep eligible patients, keep if relevant medcode or enttype, append to main
frame change combine
clear

foreach X of local filelist {
	frame import {
		di "`X'"
		import delim "$extract/`X'", clear stringcols(1 5 7 8 14 16/23)
		sort patid
		frlink m:1 patid, frame(patlist)
		count
		keep if patlist<.
		drop patlist
		count
		sort medcode
		frlink m:1 medcode, frame(codes)
		capture destring enttype, replace 
		keep if codes<. | enttype==4 | enttype==13 | enttype==14 | enttype==23 | enttype==163 ///
			| enttype==175 |enttype==177 | enttype==202 | enttype==206 |  enttype==214 ///
			| enttype==363 |  enttype==461 		
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

count
drop if date<uts
count

*** Save
order patid date
sort patid date medcode
save data/raw/stata/over65s_Test.dta, replace





**# Extract records from (single) referral file
frame change combine
clear

*** import and keep records of interest
di "medrev_Extract_Referral_001.txt"
import delim "$extract/medrev_Extract_Referral_001.txt", clear stringcols(1 5 7 8 14)
sort patid
frlink m:1 patid, frame(patlist)
count
keep if patlist<.
drop patlist
count
sort medcode
frlink m:1 medcode, frame(codes)
keep if codes<.
drop codes
count

*** new date variable, and drop if recorded before UTS
sort patid
gen date=date(eventdate,"DMY")
gen date2=date(sysdate,"DMY")
replace date=date2 if date==.
format date %dD/N/CY
drop date2

frlink m:1 patid, frame(patlist)
frget uts, from(patlist)

count
drop if date<uts
count

*** Save
order patid date
sort patid date medcode
save data/raw/stata/over65s_Referral.dta, replace



**# Extract records from (single) immunisation file (NOTE no obs with current codelists)
frame change combine
clear

*** Import and keep records of interest
di "medrev_Extract_Immunisation_001.txt"
import delim "$extract/medrev_Extract_Immunisation_001.txt", clear stringcols(1 5 7 8 14)
sort patid
frlink m:1 patid, frame(patlist)
count
keep if patlist<.
drop patlist
count
sort medcode
frlink m:1 medcode, frame(codes)
keep if codes<.
drop codes
count

*** new date variable, and drop if recorded before UTS
sort patid
gen date=date(eventdate,"DMY")
gen date2=date(sysdate,"DMY")
replace date=date2 if date==.
format date %dD/N/CY
drop date2

frlink m:1 patid, frame(patlist)
frget uts, from(patlist)

count
drop if date<uts
count

*** Save
order patid date
sort patid date medcode
save data/raw/stata/over65s_Immunisation.dta, replace




*************************************
capture log close extract
frames reset
exit
