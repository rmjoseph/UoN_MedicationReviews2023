** Created 2022-05-30 by Rebecca Joseph, University of Nottingham
*************************************
* Name:	prep_over65s_extractadditional.do
* Creator:	RMJ
* Date:	20220530	
* Desc: Extracts records from the additional files
* Notes: Needs frameappend. 
*	Date	Reference	Update
* 20220530	prep_ad_extractadditional	create file
* 20220531	prep_over65s_extractadditional	add the additional lipid enttypes
* 20220601	prep_over65s_extractadditional	add enttype 372
*************************************

** log
capture log close addit
local date: display %dCYND date("`c(current_date)'", "DMY")
log using "logs/over65s_extract_additional_`date'.txt", text append name(addit)

** working directory and root antidepressants data directory
cd R:/DRS-MedReview

** clear memory
set more off
frames reset


********************************
frame create import

**# list of people eligible for cohort, alongside their UTS date
frame create patlist
frame patlist {
	use data/prepared/over65s/over65s_cohortfile.dta
	keep if eligible==1
	keep patid uts
	sort patid
}

**# Extract records with approp enttype from Additional files
*** local macro with names of all Additional files
local filelist: dir "data/raw/over65s/extract_20220523" files "medrev_Extract_Additional_*.txt"
di `filelist'

*** Looping over files, load extract and append
foreach X of local filelist {
	frame import {
		di "`X'"
		import delim "data/raw/over65s/extract_20220523/`X'", clear stringcol(_all)
		destring enttype, replace
		keep if enttype==4 | enttype==13 | enttype==14 | enttype==23 | enttype==163 ///
			| enttype==175 |enttype==177 | enttype==202 | enttype==206 |  enttype==214 ///
			| enttype==363 |  enttype==461 | enttype==372
	
	}
	
	frameappend import
}

*** Keep if in patient list
frlink m:1 patid, frame(patlist)
keep if patlist<.
drop patlist

**# Save
sort patid
save data/raw/stata/over65s_Additional.dta, replace




**
frames reset
capture log close addit
exit
