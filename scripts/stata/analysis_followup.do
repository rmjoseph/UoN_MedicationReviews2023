* Created 22 Feb 2023 by Rebecca Joseph, University of Nottingham
*************************************
* Name:	analysis_Q1_v2.do
* Creator:	RMJ
* Date:	20230222	
* Desc: Output numbers for study population flow chart
* Notes: Define arg 'cohort'.
* Version History:
*	Date	Reference	Update
* 20230222	analysis_Q1_v2	New file
* 20230223	analysis_followup	Add sensitivity loop for part 1
*************************************

** NEED TO RUN THIS FROM THE MASTERFILE SO ARGUMENT 'COHORT' IS DEFINED
args cohort
di "`cohort'"

***
frames reset

*** log
capture log close q1
local date: display %dCYND date("`c(current_date)'", "DMY")
log using "logs/`cohort'_studypop_`date'.txt", text replace name(studypop)
log using "outputs/`cohort'_studypop.txt", text replace name(studypopout)




**# Analysis 1
use "data/prepared/`cohort'/`cohort'_prepared_dataset_Q1.dta", clear

* Study population definition - analysis 1
forval M=1/2 {	// 1
	display as result "Sensitivity loop `M'"
	local sens 
	if `M'==2 local sens "_s"

	preserve
	
	** Counts without dropping
	di as result "** Counts without dropping"
	di "Overall"
	count
	di "0 days follow-up"		
	count if enddate`sens'==index
	di "0 days follow-up and medreview index"		
	count if enddate`sens'==index & medreview`sens'==1 
	di "Missing sex"
	count if sex==.
	di "Missing sex OR 0 days follow-up"			
	count if sex==. | index==enddate`sens'
	di "No baseline meds"			
	count if polypharm==0

	** Counts with sequential dropping
	di as result "** Counts with sequential dropping"
	di "Overall"
	count
	di "Missing sex"
	count if sex==.
	drop if sex==.
	di "Count after dropping missing sex"
	count

	di "0 days follow-up"	
	count if enddate`sens'==index
	di "0 days of follow-up and medreview on index"
	count if enddate`sens'==index & medreview`sens'==1
	drop if enddate`sens'==index
	di "Count after dropping no follow-up"
	count
	
	di "// no active meds at baseline"
	count if polypharm==0
	di "// final population"
	drop if polypharm==0
	count

	restore

}

clear

**# Analysis 2 and 3 (loop)
use patid sex index enddate medreview* elig* using "data/prepared/`cohort'/`cohort'_prepared_dataset_Q2.dta", clear
duplicates drop

** Analysis: 1 = main, 2 = 6 months, 3 = 4months, 4 = 1 month

forval M=1/2 {	// 1
	display as result "Sensitivity loop `M'"
	local sens 
	if `M'==2 local sens "_s"
	
	forval A=1/4 { // 2
		preserve
		display as result "Analysis loop `A'"
			
		** Counts without dropping
		di as result "** Counts without dropping"
		di "Overall"
		count
		di "Missing sex"		
		count if sex==. 
		di "No medication review"
		count if medreview`sens'==0 
		di "Less than minimum follow-up"
		count if elig`A'==0 

		** Counts with sequential dropping
		di as result "** Counts with sequential dropping"
		di "Overall"
		count
		
		di "Missing sex"
		count if sex==.
		drop if sex==.
		di "After dropping missing sex"		
		count

		di "No medication review"		
		count if medreview`sens'==0 // no medication review
		drop if medreview`sens'==0
		di "After dropping no medication review"		
		count

		di "Less than minimum follow-up"		
		count if elig`A'==0 // less than minimum months follow-up
		drop if elig`A'==0
		
		di "Final pop"		
		count
		
		restore
	}
}



frames reset
log close studypop
log close studypopout
exit

