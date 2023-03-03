** Created 2022-04-06 by Rebecca Joseph, University of Nottingham
*************************************
* Name:	prep_ad_definecohort.do
* Creator:	RMJ
* Date:	20220406	
* Desc:	Defines eligibility and index date for antidep cohort. Also links townsend.
* Notes: 
* Version History:
*	Date	Reference	Update
* 20220406	new file	create file
* 20220519	prep_ad_definecohort	Merge in townsend data
* 20220520	prep_ad_definecohort	Rename save location to ad/ (from antidepressant_data/)
* 20220530	prep_ad_definecohort	Change patid and pracid to strings
* 20220531	prep_ad_definecohort	Add ageatindex var
* 20220531	prep_ad_definecohort	gen studywindowend and patfupend
* 20220627	prep_ad_definecohort	BUG: fix def of pracid so practices link
* 20230302	prep_ad_definecohort	Tidy script
* 20230303	prep_ad_definecohort	Update file paths for sharing
*************************************

** log
capture log close adcohort
local date: display %dCYND date("`c(current_date)'", "DMY")
log using "logs/defineADcohort_`date'.txt", text append name(adcohort)

** clear memory
set more off
frames reset


*************************************

**# Load datasets
** Load Define patient list 
*	- 18+ at index, 1year UTS at index, 1year followup at index
*	- antidep code within UTS registration period, any in study period
*	- study period 01/01/2019 - 31/12/2019
frame create define
frame define {
	import delim using "data/raw/ad/g_ad2019_Define_results.txt", stringcol(_all)
	gen index = floor(date(indexdate,"DMY"))
	format index %dD/N/CY
	drop indexdate
	}

** Load practice file	
frame create practice
frame practice: import delim using "data/raw/ad/gold_patid1_Extract_Practice_001.txt", stringcol(1)

	
** Load patient file & combine
import delim using "data/raw/ad/gold_patid1_Extract_Patient_001.txt", stringcol(1)
keep patid gender yob frd crd tod deathdate
*gen pracid = real(substr(string(patid, "%12.0g"),-3,3))
gen pracid=real(substr(patid,-3,3))
tostring pracid, replace
order pracid, after(patid)

frlink m:1 pracid, frame(practice)
frget *, from(practice)
drop practice

frlink 1:1 patid, frame(define)
keep if define<.
frget *, from(define)
drop define


** Label variables
rename gender sex
recode sex (1=0) (2=1) (3=.)

label var patid "CPRD patient identifier"
label var pracid "CPRD practice identifier"
label var sex "Sex, 0=male 1=female .=indeterminate/unknown"
label var region "CPRD practice region"
label var yob "CPRD year of birth"
label var index "First antidep in 2019"

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
7	"South West"
8	"South Central"
9	"London"
10	"South East Coast"
11	"Northern Ireland"
12	"Scotland"
13	"Wales" ;
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




**# Eligibility 
egen cprdstart = rowmax(uts frd crd)
replace cprdstart = cprdstart + 365
egen cprdend = rowmin(tod deathdate lcd)
format cprdstart cprdend %dD/N/CY

label var cprdstart "Latest of registration date or uts, plus 365days"
label var cprdend "Earliest of death date, last collection date, transfer out date"

gen plus18 = string(yob + 18)
gen date18=date(plus18,"Y")
drop plus18
format date18 %dD/N/CY
label var date18 "Date of turning 18, set to 01/01/(yob+18)"

egen fupstart=rowmax(cprdstart date18 index)
format fupstart %dD/N/CY
label var fupstart "Latest of cprdstart, date18, index" 

gen elig_fup = (cprdstart<=cprdend)
gen eligible = (fupstart<=cprdend) & (index==fupstart)

label var elig_fup "start of CPRD followup on/before end of CPRD followup"
label var eligible "first antidep on/after cprdstart & on/before cprdend"


**# Merge in townsend data
frame create SES
frame SES {
	import delim using "data/raw/ad/patient_townsend2001_20_000059.txt", stringcol(1 2)
	}
frlink 1:1 patid, frame(SES)
frget townsend2001_5, from(SES)
drop SES
rename townsend2001_5 townsend
label var townsend "Townsend 2001 quintile"


** Age variable
gen ageatindex = year(index)-yob
label variable ageatindex "Age (years) in index year"


** Follow-up end for this cohort
gen studywindowend=date("31/12/2019","DMY")
format studywindowend %dD/N/CY
label var studywindowend "End of study window (31 Dec 2019)"

egen patfupend=rowmin(studywindowend cprdend)
format patfupend %dD/N/CY
label var patfupend "Earliest of studywindowend cprdend"


**# tidy and save
order patid pracid eligible index sex region yob townsend
sort patid

save data/prepared/ad/ad_cohortfile, replace



*************************************
frames reset
capture log close adcohort
exit
