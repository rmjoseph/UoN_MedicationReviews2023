** Created 2022-05-30 by Rebecca Joseph, University of Nottingham
*************************************
* Name:	prep_over65s_extractconstype.do
* Creator:	RMJ
* Date:	20220530	
* Desc:	Loads consultation files, gets constype, merge with lookup.
* Notes: Needs frameappend
* Version History:
*	Date	Reference	Update
* 20220530	prep_ad_extractconstype	create file
* 20220531	prep_ad_extractconstype	rename var cprdfupstop cprdend
* 20230302	prep_ad_extractconstype	Tidy script
*************************************

** log
capture log close consultation
local date: display %dCYND date("`c(current_date)'", "DMY")
log using "logs/over65s_extract_constype_`date'.txt", text append name(consultation)

** working directory and root antidepressants data directory
cd R:/DRS-MedReview

** clear memory
set more off
frames reset

*************************************

**# list of people eligible for cohort. 
frame create patlist
frame patlist {
	use data/prepared/over65s/over65s_cohortfile.dta
	keep if eligible==1
	keep patid uts index cprdend
	sort patid
}

**# list of medcodes
frame create codes
frame codes {
	import delim using data/raw/codelists/polypharm_consultationtypes_gold.csv
	duplicates drop
}

**# Extract records from consultation file, keeping records from index-1 year to 
***	cprdend.
frame create import
frame create combine

*** local macro with names of all Consultation files
local filelist: dir "data/raw/over65s/extract_20220523" files "medrev_Extract_Consultation_*.txt"
di `filelist'

*** Looping over each file: import, required vars, records in time window,
*** drop duplicates, append 
frame change combine
clear

foreach X of local filelist {
	frame import {
		di "`X'"
		import delim "data/raw/over65s/extract_20220523/`X'", clear stringcol(1 5)
		
		gen date=date(eventdate,"DMY")
		gen date2=date(sysdate,"DMY")
		replace date=date2 if date==.
		
		frlink m:1 patid, frame(patlist)
		frget *, from(patlist)
		drop if patlist==.
		drop patlist
		
		drop if date<date("01/01/2018","DMY")
		drop if date>cprdend
		
		keep patid consid constype
		duplicates drop

	}
	frameappend import
}

frlink m:1 patid, frame(patlist)
keep if patlist<.
drop patlist

frlink m:1 constype, frame(codes)
frget category, from(codes)
drop codes

rename category cot
label variable cot "Categorised consultation type, 1=face to face, 2=phone,3=other"
rename constype constype_o
label variable constype "Orig consultation type from consultation file"

keep patid consid constype_o cot
duplicates drop


*** Save
sort patid consid
save data/prepared/over65s/consultationtypes.dta, replace




*************************************
capture log close consultation
frames reset
exit
