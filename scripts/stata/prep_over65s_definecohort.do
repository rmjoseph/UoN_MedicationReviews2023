** Created 2022-05-27 by Rebecca Joseph, University of Nottingham
*************************************
* Name:	prep_over65s_definecohort.do
* Creator:	RMJ
* Date:	20220527	
* Desc:	Defines eligibility and index date for over 65s cohort. Also links townsend.
* Notes: 
* Version History:
*	Date	Reference	Update
* 20220527	new file	create file
* 20220531	prep_over65s_definecohort	rename vars cprdfupstart/stop cprdstart cprdend
* 20220531	prep_over65s_definecohort	gen studywindowend and patfupend
* 20220609	prep_over65s_definecohort	import and merge townsend files
* 20230302	prep_over65s_definecohort	Tidy script
*************************************

** log
capture log close cohort
local date: display %dCYND date("`c(current_date)'", "DMY")
log using "logs/over65s_cohort_`date'.txt", text append name(cohort)


** clear memory
set more off
frames reset


*************************************
** Cohort already defined - patient file contains only eligible people (see prep_over65s_patientlist.do).
** Load patient and practice files. Combine.
import delim using "data/raw/over65s/extract_20220523/medrev_Extract_Patient_001.txt", stringcols(1)
gen pracid=substr(patid,-5,.)

frame create practice
frame practice: import delim using "data/raw/over65s/extract_20220523/medrev_Extract_Practice_001.txt", stringcols(1)
frlink m:1 pracid, frame(practice)
frget *, from(practice)
drop practice


** Label variables
rename gender sex
recode sex (1=0) (2=1) (3=.)

label var patid "CPRD patient identifier"
label var pracid "CPRD practice identifier"
label var sex "Sex, 0=male 1=female .=indeterminate/unknown"
label var region "CPRD practice region"
label var yob "CPRD year of birth"

#delimit;
label define sex 
0	"Male"
1	"Female" ;

label define region 
1	"North East"
2	"North West"
3	"Yorkshire & The Humber"
4	"East Midlands"
5	"West Midlands"
6	"East of England"
7	"London"
8	"South East"
9	"South West"
10	"Wales"
11	"Scotland"
12	"Northern Ireland" ;
#delimit cr

label values sex sex
label values region region

** Reformat string dates as numeric dates
foreach X of varlist uts frd crd tod deathdate lcd {
	rename `X' temp 
	gen `X' = date(temp,"DMY")
	format `X' %dD/N/CY
	drop temp
	}
label var uts "CPRD practice up-to-standard date"
label var frd "CPRD first registration date"
label var crd "CPRD current registration date"
label var tod "CPRD transfer out date (leaving practice)"
label var deathdate "CPRD death date"
label var lcd "CPRD last collection date"	


** Keep useful variables & create index (01 Jan 2019 for all)
keep patid pracid sex yob region uts frd crd tod deathdate lcd 
gen index=date("01/01/2019","DMY")
format index %dD/N/CY
label variable index "Date of joining cohort"

** CPRD followup dates
egen cprdstart = rowmax(uts frd crd)
replace cprdstart = cprdstart + 365.25
egen cprdend = rowmin(tod deathdate lcd)
format cprdstart cprdend* %dD/N/CY
label var cprdstart "Max of uts frd crd, plus 365.25 days"
label var cprdend "Min of tod deathdate lcd"

** Follow-up end date
gen studywindowend=date("31/12/2019","DMY")
format studywindowend %dD/N/CY
label var studywindowend "End of study window (31 Dec 2019)"

egen patfupend=rowmin(studywindowend cprdend)
format patfupend %dD/N/CY
label var patfupend "Earliest of studywindowend cprdend"

** Age variable
gen ageatindex = 2019-yob
label variable ageatindex "Age (years) in 2019"

** Make eligibility flag to match other cohort (all should be eligible)
gen eligible=(ageatindex>=65 & cprdstart<=index & cprdend>=index)
label variable eligible "Eligibility flag"

**# Merge in townsend data (patient and practice)
frame create tpat
frame tpat {
	 clear
	 import delimited "data/raw/over65s/townsend/patient_townsend2011_22_001767.txt", stringcols(1 2) 
}

frame create tprac
frame tprac {
	clear
	import delimited "data/raw/over65s/townsend/practice_imd_22_001767.txt", stringcols(1)
}

frlink 1:1 patid, frame(tpat)
frget e2011_townsend, from(tpat)
drop tpat

frlink m:1 pracid, frame(tprac)
frget uk2011_townsend, from(tprac)
drop tprac

gen townsend=e2011_townsend
replace townsend=uk2011_townsend if townsend==.

drop e2011_townsend uk2011_townsend
label variable townsend "2011 Townsend score quintile (practice or patient level)"

**# tidy and save 
order patid pracid eligible index sex region yob townsend
sort patid

save data/prepared/over65s/over65s_cohortfile, replace




*************************************
frames reset
capture log close cohort
exit
