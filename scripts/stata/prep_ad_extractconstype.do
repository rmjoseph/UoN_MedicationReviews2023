** Created 2022-05-30 by Rebecca Joseph, University of Nottingham
*************************************
* Name:	prep_ad_extractconstype.do
* Creator:	RMJ
* Date:	20220530	
* Desc:	Loads consultation files, gets constype, merge with lookup.
* Notes: Needs frameappend
* Version History:
*	Date	Reference	Update
* 20220530	new file	create file
* 20230303	prep_ad_extractconstype	Update file paths for sharing
*************************************

** log
capture log close consultation
local date: display %dCYND date("`c(current_date)'", "DMY")
log using "logs/ad_extract_constype_`date'.txt", text append name(consultation)


** clear memory
set more off
frames reset

*************************************

**# list of people eligible for cohort. 
frame create patlist
frame patlist {
	use data/prepared/ad/ad_cohortfile.dta
	keep if eligible==1
	keep patid uts index cprdend
	gen oneyearbef= index-365
	format oneyearbef %dD/N/CY
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
local filelist: dir "data/raw/ad" files "gold_patid1_Extract_Consultation_*.txt"
di `filelist'

*** Looping over each file: import, required vars, records in time window,
*** drop duplicates, append 
frame change combine
clear

foreach X of local filelist {
	frame import {
		di "`X'"
		import delim "data/raw/ad/`X'", clear stringcol(1 5)
		
		gen date=date(eventdate,"DMY")
		gen date2=date(sysdate,"DMY")
		replace date=date2 if date==.
		
		frlink m:1 patid, frame(patlist)
		frget *, from(patlist)
		drop if patlist==.
		drop patlist
		
		drop if date<oneyearbef
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
save data/prepared/ad/consultationtypes.dta, replace




*************************************
capture log close consultation
frames reset
exit
