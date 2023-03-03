** Created 2023-01-11 by Rebecca Joseph, University of Nottingham
*************************************
* Name:	prep_Q2_dataset_v2.do
* Creator:	RMJ
* Date:	20230111	
* Desc:	Combines all vars needed for analysis Q2
* Notes: 
* Version History:
*	Date	Reference	Update
* 20220901	new file	create file
* 20220908	prep_Q2_dataset.do	bug fix use cohort not ad in merge
* 20221003	prep_Q2_dataset.do	update analysis label to include 1month windows
* 20221003	prep_Q2_dataset.do	bug fix use _s versions of cot and role for sensitivity
* 20221012	prep_Q2_dataset.do	update to handle updated count vars
* 20230111	prep_Q2_dataset.do	Save new version
* 20230111	prep_Q2_dataset_v2.do	Different reshape approach + add in bl vars
* 20230119	prep_Q2_dataset_v2.do	Add enddate and index to file
*************************************

** NEED TO RUN THIS FROM THE MASTERFILE SO ARGUMENT 'COHORT' IS DEFINED
args cohort
di "`cohort

frames reset


*** Baseline covars & eligibility flags for Q2
use patid sex enddate enddate_s index medreview* pracid age* ethnicity townsend region* firstrev_staffrole* firstrev_cot* using "data/prepared/`cohort'/`cohort'_prepared_dataset_Q1.dta", clear
order agecat, after(ageatindex)


**** Simplifying var names & labels
rename firstrev_staffrole staffrole
rename firstrev_staffrole_s staffrole_s

rename firstrev_cot cot
rename firstrev_cot_s cot_s

label var townsend "Townsend score quintile"
label var staffrole "Staff role"
label var staffrole_s "Staff role"
label var cot "Consultation type"
label var cot_s "Consultation type"

label define townsend 1 "Quintile 1", modify
label define region 3 "Y&tH" 12 "N. Ireland", modify


**** Get eligibility flags for each of the time windows
merge 1:1 patid using  "data/prepared/`cohort'/timewindows_Q2_s.dta", keepusing(elig*)
drop _merge
rename elig3 elig1_s
rename elig6 elig2_s
rename elig4 elig3_s
rename elig1 elig4_s
drop eligible

merge 1:1 patid using  "data/prepared/`cohort'/timewindows_Q2.dta", keepusing(elig*)
drop _merge
rename elig1 TEMP
rename elig3 elig1
rename elig6 elig2
rename elig4 elig3
rename TEMP elig4
drop eligible

order elig1 elig2 elig3 elig4 elig1_s elig2_s elig3_s elig4_s, last




**** Load & reshape counts dataset
frame create counts
frame counts {
	
	use data/prepared/`cohort'/polypharmcounts.dta, clear
	
	**** Reshape so count vars are long
	rename countB count1
	rename countA count2
	rename countC count3
	reshape long count, i(patid analysis period) j(counttype)
	
	**** Reshape so period (before/after) is wide. Calc difference.
	reshape wide count, i(patid analysis counttype) j(period)
	rename count0 before
	rename count1 after
	gen dif=after-before
	
	**** Reshape analysis so sensitivity definition is wide
	gen sens=(analysis>4)
	replace sens=sens+1
	replace analysis=analysis-4 if sens==2
	
	reshape wide before after dif, i(patid analysis counttype) j(sens)
	sort patid analysis counttype
	
	label define analysis 1 "3 months (main)" 2 "6 months" 3 "4 months" 4 "1 month"
	label values analysis analysis	
	
	label define counttype 1 "Repeat meds only" 2 "All meds" 3 "Repeat tablets only"
	label values counttype counttype	
	
	label var analysis "Time windows around med review"
	label var counttype "Which medicines are included in counts"
	
	rename before1 before
	rename after1 after
	rename dif1 dif
	label var before "Count before review"
	label var after "Count after review"
	label var dif "Count after minus count before"
	
	rename before2 before_s
	rename after2 after_s
	rename dif2 dif_s
	label var before_s "Count before review"
	label var after_s "Count after review"
	label var dif_s "Count after minus count before"
	

	**** Categorised polypharm count before review
	egen blpoly = cut(before), at(0,1,2,5(5)20 50) icodes
	egen blpoly_s = cut(before_s), at(0,1,2,5(5)20 50) icodes

	label define polypharm 0 "0" 1 "1" 2 "2-4" 3 "5-9" 4 "10-14" ///
								5 "15-19" 6 "20+"
	label values blpoly* polypharm
	label variable blpoly "Categorised polypharmacy count before review"
	label variable blpoly_s "Categorised polypharmacy count before review"

	
}




**** Combine counts info with covars
frame counts {
	tempfile temp
	save "`temp'", replace
}

merge 1:m patid using "`temp'"
gen matched=(_merge==3)
drop _merge



*** save
save data/prepared/`cohort'/`cohort'_prepared_dataset_Q2.dta, replace

frames reset
exit
