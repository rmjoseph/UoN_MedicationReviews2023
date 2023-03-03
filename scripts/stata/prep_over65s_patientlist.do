** Created 2022-05-10 by Rebecca Joseph, University of Nottingham
*************************************
* Name:	prep_over65s_patientlist.do
* Creator:	RMJ
* Date:	20220510	
* Desc:	List of patients to request data extraction for
* Notes: 
* Version History:
*	Date	Reference	Update
* 20220510	new file	create file
* 20220512	prep_over65s_patientlist	Add part 2 defining linkage eligiblity
* 20220520	prep_over65s_patientlist	Rename dir over65s_data (old) over65s (new)
* 20230302	prep_over65s_patientlist	Tidy script
*************************************

cd "R:/DRS-MedReview"
frames reset

** log
capture log close cohortelig
local date: display %dCYND date("`c(current_date)'", "DMY")
log using "logs/over65s_cohorteligiblity_`date'.txt", text append name(cohortelig)



**# Part 1 - eligibile population
** Open and combine patient and practice denominators
import delimited using "data/raw/202205_Denom/acceptable_pats_from_utspracts_2022_05.txt", stringcols(1)
gen pracid = substr(patid,-5,.)

frame create practice
frame practice {
	import delimited using "data/raw/202205_Denom/allpractices_MAY2022.txt", stringcols(1)
}

frlink m:1 pracid, frame(practice)
frget *, from(practice)
drop practice

** Format date variables
foreach X of varlist uts lcd tod frd crd deathdate {
	rename `X' date
	gen `X' = date(date,"DMY")
	format `X' %dD/N/CY
	drop date
}

** Calculate start and end of CPRD follow-up, and age in 2019
egen fupstart = rowmax(uts frd crd)
egen fupend = rowmin(tod lcd deathdate)
format fupstart fupend %dD/N/CY
gen age2019 = 2019-yob

** Apply inclusion criteria:
*** Aged 65+ in 2019
count
keep if age2019>=65

*** 1+ years of followup before 01 Jan 2019
count
keep if fupstart<=date("01/01/2018","DMY")

*** remain in cohort by 2019
count
keep if fupend>=date("01/01/2019","DMY")

count
count if fupend==date("01/01/2019","DMY") // 201 have <1 day follow-up

*** Export patient list
keep patid pracid
destring patid, gen(patid2)
sort patid2
export delimited patid using "data/prepared/over65s/22_001767_studypop_patids.txt", delim(tab) replace novarnames





**# Part 2: list of patients and practices for linkage request
frame create linkage
frame linkage {
	import delimited using "data/raw/LinkageEligibility/GOLD_enhanced_eligibility_January_2022.txt", stringcols(1 2) clear
}

*** practices (all practices)
frame put pracid, into(praclist)
frame praclist {
	duplicates drop
	count
	destring pracid, gen(prac2)
	sort prac2
	export delimited pracid using "data/prepared/over65s/22_001767_UniNottingham_practicelist.txt", delim(tab) replace
}

*** patients
frame change default
drop pracid

frlink 1:1 patid, frame(linkage)
keep if linkage<.
frget *, from(linkage)
keep if lsoa_e==1
count

*** patids
export delimited patid lsoa_e using "data/prepared/over65s/22_001767_UniNottingham_patientlist.txt", delim(tab) replace



capture log close cohortelig
frames reset
exit
