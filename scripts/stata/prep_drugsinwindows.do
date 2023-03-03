** Created 2022-07-06 by Rebecca Joseph, University of Nottingham
*************************************
* Name:	prep_drugsinwindows.do
* Creator:	RMJ
* Date:	20220706	
* Desc: Load/append al pescription datasets, keeping records within each 
*		time window of interest. [cut - move elsewhere ... Process to get drug names/bnf info for 
*		prescriptions in each window & count max number of drugs.]
* Notes: frameappend, tvc_split. Define arg 'cohort'.
* Version History:
*	Date	Reference	Update
* 20220706	new file	Create file
* 20220712	prep_drugsinwindows	Do not merge drug info so files aren't huge
* 20220712	prep_drugsinwindows	Add error capture step so frameappend doesn't fail
* 20220712	prep_drugsinwindows	Replace "ad" with "`cohort'" in program
* 20220720	prep_drugsinwindows	Update dates logic so keep based on start not stop & < not <=
* 20220720	prep_drugsinwindows	Dif rules for drugs active on date vs presc'd in window
* 20220720	prep_drugsinwindows	Run only once for index dataset... should be no difs
* 20220825	prep_drugsinwindows	Extra dataset for 6m up to index
* 20220826	prep_drugsinwindows	Keep var issueseq when processing prescn data
* 20220902	prep_drugsinwindows	BUG FIX! used "ad" instead of `cohort' in bldrugs
* 20221003	prep_drugsinwindows	Add sections for r-1m and r+1m
* 20230302	prep_drugsinwindows	Tidy file
*************************************

** NEED TO RUN THIS FROM THE MASTERFILE SO ARGUMENT 'COHORT' IS DEFINED
args cohort
di "`cohort'"

** Log
capture log close windows
local date: display %dCYND date("`c(current_date)'", "DMY")
log using logs/drugsinwindows_`cohort'_`date'.txt, text replace name(windows)
frames reset


**# Load and combine reference datasets
*** Cohort
frame create cohort1
frame cohort1: use patid index eligible cprdend if eligible==1 using data/prepared/`cohort'/`cohort'_cohortfile.dta

frame copy cohort1 cohort2

*** Time windows
frame create dates1
frame dates1: use data/prepared/`cohort'/timewindows_Q2.dta 

frame create dates2
frame dates2: use data/prepared/`cohort'/timewindows_Q2_s.dta 

*** Combine
frame cohort1 {
	drop eligible
	frlink 1:1 patid, frame(dates1)
	frget *, from(dates1)
	drop dates1
	gen indmin6=floor(index-(365/2))
}

frame cohort2 {
	drop eligible
	frlink 1:1 patid, frame(dates2)
	frget *, from(dates2)
	drop dates2
}


**# Define program to load presc files, keep records in windows, append, and...
***	list drug names/bnf chapters/bnfcodes and max count of drugs in window.
capture program drop DRUGSINWINDOW
program define DRUGSINWINDOW

	syntax, windowend(name) windowstart(name) [index] cohortname(string asis) // [split]  
	
		di "windowend: `windowend'"
		di "windowstart: `windowstart'"
		if "`index'"!="" di "Keep if: active on single date"
		else di "Keep if: prescribed during window"		
		di "cohort: `cohortname'"
		if "`split'" !="" di "split? yes"
		else di "split? no"

	local filelist: dir "data/prepared/`cohortname'" files "prescriptions_chapter*.dta"

	*** Load each prescription file, keep records within specified window, append
	tempname load
	frame create `load'
	foreach F of local filelist {
		frame `load' {
			
			di "`F'"
			
			clear
			use patid prodcode issueseq formulation dosekey start stop using	"data/prepared/`cohortname'/`F'"
			
			frlink m:1 patid, frame(cohort)
			keep if cohort<.
			frget *, from(cohort)
			drop cohort
			
			drop if `windowend'==.
			drop if `windowstart'==.
			if "`index'"!="" keep if start<=`windowend' & stop>`windowstart' // single date
			else keep if start>=`windowstart' & start<`windowend' // time window
			
			keep patid prodcode issueseq formulation dosekey start stop `windowend' `windowstart'
			count
		}
		
		if `r(N)'!=0 frameappend `load'
	}	


	
end
	

	

**# Run and save for each time window and for the 2nd med reviews definition
*** Drugs ON index
frame copy cohort1 cohort

frame change default
clear
di "$S_DATE $S_TIME"
DRUGSINWINDOW, windowend(index) windowstart(index) index cohortname(`cohort')
save data/prepared/`cohort'/drugsinwindow_index.dta, replace

frame drop cohort


*** Drugs in 6 months up to AND INCLUDING index
frame copy cohort1 cohort
frame cohort: replace index=index+1 // so prescs ON index are counted 

frame change default
clear
di "$S_DATE $S_TIME"
DRUGSINWINDOW, windowend(index) windowstart(indmin6) cohortname(`cohort')
save data/prepared/`cohort'/drugsinwindow_index_min6.dta, replace

frame drop cohort


*** now loop for remaining windows (loop for normal/sensitivity)
forval N=1/2 {
	frame change default
	frame copy cohort`N' cohort
	
	*** R-3m
	di "$S_DATE $S_TIME"
	clear
	DRUGSINWINDOW, windowend(review) windowstart(r_minus3) cohortname(`cohort') //split
	if `N'==1 save data/prepared/`cohort'/drugsinwindow_3mpre.dta, replace
	if `N'==2 save data/prepared/`cohort'/drugsinwindow_3mpre_s.dta, replace

	*** R-6m
	clear
	di "$S_DATE $S_TIME"
	DRUGSINWINDOW, windowend(review) windowstart(r_minus6) cohortname(`cohort') //split
	if `N'==1 save data/prepared/`cohort'/drugsinwindow_6mpre.dta, replace
	if `N'==2 save data/prepared/`cohort'/drugsinwindow_6mpre_s.dta, replace

	*** R-1m
	clear
	di "$S_DATE $S_TIME"
	DRUGSINWINDOW, windowend(review) windowstart(r_minus1) cohortname(`cohort') //split
	if `N'==1 save data/prepared/`cohort'/drugsinwindow_1mpre.dta, replace
	if `N'==2 save data/prepared/`cohort'/drugsinwindow_1mpre_s.dta, replace
	
	*** R+3m 
	clear
	di "$S_DATE $S_TIME"
	DRUGSINWINDOW, windowend(r_plus3) windowstart(review) cohortname(`cohort') //split
	frlink m:1 patid, frame(cohort`N')
	frget elig3, from(cohort`N')
	drop cohort`N'
	
	if `N'==1 save data/prepared/`cohort'/drugsinwindow_3mpost.dta, replace
	if `N'==2 save data/prepared/`cohort'/drugsinwindow_3mpost_s.dta, replace

	*** R+6m
	di "$S_DATE $S_TIME"
	clear
	DRUGSINWINDOW, windowend(r_plus6) windowstart(review) cohortname(`cohort') //split
	frlink m:1 patid, frame(cohort`N')
	frget elig6, from(cohort`N')
	drop cohort`N'
	
	if `N'==1 save data/prepared/`cohort'/drugsinwindow_6mpost.dta, replace
	if `N'==2 save data/prepared/`cohort'/drugsinwindow_6mpost_s.dta, replace

	*** R+1m
	di "$S_DATE $S_TIME"
	clear
	DRUGSINWINDOW, windowend(r_plus1) windowstart(review) cohortname(`cohort') //split
	frlink m:1 patid, frame(cohort`N')
	frget elig1, from(cohort`N')
	drop cohort`N'

	if `N'==1 save data/prepared/`cohort'/drugsinwindow_1mpost.dta, replace
	if `N'==2 save data/prepared/`cohort'/drugsinwindow_1mpost_s.dta, replace
	
	*** R+1m to R+4m
	di "$S_DATE $S_TIME"
	clear
	DRUGSINWINDOW, windowend(r_plus4) windowstart(r_plus1) cohortname(`cohort') //split
	frlink m:1 patid, frame(cohort`N')
	frget elig4, from(cohort`N')
	drop cohort`N'

	if `N'==1 save data/prepared/`cohort'/drugsinwindow_4mpost.dta, replace
	if `N'==2 save data/prepared/`cohort'/drugsinwindow_4mpost_s.dta, replace

		
	frame drop cohort
	di "$S_DATE $S_TIME"
}


capture log close windows

****
frames reset
exit

