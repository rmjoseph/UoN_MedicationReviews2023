** Created 2022-06-27 by Rebecca Joseph, University of Nottingham
*************************************
* Name:	prep_import_prescriptions.do
* Creator:	RMJ
* Date:	202206027	
* Desc:	Import raw therapy files and save as .dta files by BNF chapter
* Notes: frameappend. Define arg 'cohort'.
* Version History:
*	Date	Reference	Update
* 20220627	new file	Create file
* 20230303	prep_import_prescription	Update file paths for sharing
*************************************

** RUN FROM MASTER FILE
args cohort
di "`cohort'"


** Log
local date: display %dCYND date("`c(current_date)'", "DMY")
di `date'
local logname: display "import_prescriptions_`cohort'_"`date'
di "`logname'"

capture log close presc
log using "logs/`logname'.log", append name(presc)


** frames reset
frames reset
set more off

*****************************************

**# Load files into frames, set up macros
** Cohort file: patid and uts
frame create cohort
frame cohort {
	use patid uts using data/prepared/`cohort'/`cohort'_cohortfile.dta
	sort patid
	
}

** BNF chapter file
frame create bnf
frame bnf {
	use prodcode chapter using data/prepared/`cohort'/bnfchapters_clean.dta
	replace chapter=14 if chapter>14
	sort prodcode
}

** New dosage id to replace doseid
frame create newdose
frame newdose {
	use data/prepared/`cohort'/dosage_key.dta
	sort dosageid
}

** Directory with raw files
if "`cohort'"=="ad" {
	local filedir data/raw/ad
	di "`filedir'"
}
if "`cohort'"=="over65s" {
	local filedir data/raw/over65s/extract_20220523
	di "`filedir'"
}

** Name of raw files
if "`cohort'"=="ad" {
	local filename "gold_patid1_Extract_Therapy_*.txt"
	di "`filename'"
}
if "`cohort'"=="over65s" {
	local filename "medrev_Extract_Therapy_*.txt"
	di "`filename'"
}



**# Open each therapy file. Create date var and keep records after UTS. 
*** Replace dosageid. Put each chapter into new frame and either save (if first) or
*** append to other records.
local filelist: dir "`filedir'" files "`filename'"
di `filelist'

local counter 0
foreach F of local filelist {

	local counter = `counter' + 1
	display "$S_TIME  $S_DATE"
	di "`F'"
	di "`counter'"
	
	** Open file
	if "`cohort'"=="over65s" { 
		import delim "`filedir'/`F'", stringcol(1 6) clear
	}
	else {
		import delim "`filedir'/`F'", stringcol(1) clear		
	}
	
	** Keep if part of cohort file
	sort patid
	frlink m:1 patid, frame(cohort)
	keep if cohort<.
	
	** Replace dosageid with dosekey
	sort dosageid
	frlink m:1 dosageid, frame(newdose)
	frget *, from(newdose)
	drop dosageid newdose
	
	** Gen new date var (fill in any missing eventdate with sysdate)
	replace eventdate=sysdate if eventdate==""
	drop sysdate
	rename eventdate temp
	gen eventdate=date(temp,"DMY")
	format eventdate %dD/N/CY
	drop temp
	
	** Drop if eventdate is < uts
	frget uts, from(cohort)
	drop if eventdate<uts
	drop cohort uts

	** Get BNF chapter
	sort prodcode
	frlink m:1 prodcode, frame(bnf)
	frget chapter, from(bnf)
	drop bnf
	
	** by chapter, put records into file and append/save
	order patid eventdate	
	forval C = 1/14 {
		frame put * if chapter==`C', into(temp)
		drop if chapter==`C'
		
		frame temp {
			capture confirm file "data/raw/stata/`cohort'_therapy_bnfchapter`C'.dta"
			if `counter'==1 {
				di "Start of re-run: delete existing file"
				save "data/raw/stata/`cohort'_therapy_bnfchapter`C'.dta", replace				
			}
			if `counter'>1 {
				di "Mid-loop: append"
				append using "data/raw/stata/`cohort'_therapy_bnfchapter`C'.dta"
				save "data/raw/stata/`cohort'_therapy_bnfchapter`C'.dta", replace
			}
		}
		frame drop temp
	} // close loop C
	
	
} // close loop F



*****************************************
display "$S_TIME  $S_DATE"
frames reset
capture log close presc
exit
