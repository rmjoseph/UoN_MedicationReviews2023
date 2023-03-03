** Created 2022-06-01 by Rebecca Joseph, University of Nottingham
*************************************
* Name:	prep_define_smoking.do
* Creator:	RMJ
* Date:	20220601	
* Desc:	Defines basline smoking status.
* Notes: frameappend. Define arg 'cohort'.
* Version History:
*	Date	Reference	Update
* 20220601	[polypharmacy]/smoking_definition_master.do	Adapt file to this analysis
* 20220830	prep_define_smoking	Add in therapy section using recs from BNF 4
* 20230302	prep_define_smoking	Tidy script
*************************************

** NEED TO RUN THIS FROM THE MASTERFILE SO ARGUMENT 'COHORT' IS DEFINED
args cohort
di "`cohort'"

** Log
local date: display %dCYND date("`c(current_date)'", "DMY")
di `date'
local logname: display "prep_smoking_`cohort'_"`date'
di "`logname'"

capture log close smoking
log using "logs/`logname'.log", append name(smoking)

** frames reset
frames reset
set more off


*****************************************

**# Load & combine all files
*** Cohort file
capture frame create cohort
frame cohort {
	clear
	use data/prepared/`cohort'/`cohort'_cohortfile.dta
	keep if eligible==1
	keep patid index patfupend
	sort patid
}

*** Med codes list
capture frame create codes
frame codes {
	clear
	use medcode smoking* desc using data/prepared/`cohort'/codelists_lookup.dta
	keep if smoking==1
	sort medcode
	destring smoking_c, replace
}


*** Med records from clinical, referral, test
use patid date medcode adid using data/raw/stata/`cohort'_Clinical.dta
sort medcode
frlink m:1 medcode, frame(codes)
keep if codes<.
frget *, from(codes)

capture frame create load
foreach X of newlist Referral Test {
	frame load {
		clear
		use patid date medcode using data/raw/stata/`cohort'_`X'.dta
		sort medcode
		frlink m:1 medcode, frame(codes)
		keep if codes<.
		frget *, from(codes)
	}
	
	frameappend load

}

drop smoking codes medcode


*** Therapy records
frame load {
	
	clear
	
	use patid eventdate prodcode using "data/raw/stata/`cohort'_therapy_bnfchapter4.dta"
	duplicates drop
	bys patid prodcode (eventdate): keep if _n==1

	merge m:1 prodcode using "data/prepared/`cohort'/bnfchapters_clean.dta", keep(3) nogen
	merge m:1 prodcode using "data/prepared/`cohort'/drugnames_clean.dta", keep(3) nogen keepusing(drugname)

	keep if bnfcode_num==41002 | regexm(drugname,"varenicline|nicotine")==1
	drop if drugname=="bupropion"

	keep patid eventdate
	bys patid (eventdate): keep if _n==1
	rename eventdate firsttherapy
	sort patid
	
}

sort patid
frlink m:1 patid, frame(load)
frget *, from(load)
drop load

**** Append smoking therapy records if no clinical records to link to
frame put patid, into(temp)
frame temp: duplicates drop

frame load {
	frlink 1:1 patid, frame(temp)
	keep if temp==.
	drop temp
}

frameappend load
frame drop temp

replace date=firsttherapy if date==.



*** Additional records
frame load {
    
	clear
	use data/raw/stata/`cohort'_Additional.dta 
	keep if enttype==4 | enttype==23
	drop data5 data6 data7
	
	forval X=1/4 {
	    destring data`X', replace
	}

	drop if enttype==23 & data2!=2
	drop if enttype==4 & (data1==0 | data1>4)
}


*** Prepare additional file
frame load {
	
	*** Smoking status
	replace data1=5 if enttype==23
	recode data1 (1=4) (2=1) (3=3) (5=5)
	rename data1 ad_stat
	// 1 never 3 former 4 current 5 ever
	
	*** tidy
	keep patid adid ad_stat
	duplicates drop
	
	duplicates report patid adid
	sort patid adid
	
}

sort patid adid
frlink m:1 patid adid, frame(load)
frget *, from(load)
drop load





**# Single smoking status
*** Single sources
gen smokingstatus = .
replace smokingstatus = smoking_c if ad_stat==.
replace smokingstatus = ad_stat if smoking_c==.

*** smoking_c == ad_stat
replace smokingstatus = smoking_c if smoking_c==ad_stat & smoking_c<.

*** smoking_c != ad_stat
replace smokingstatus=3 if smoking_c==1 & ad_stat==3 & smokingstatus==.	// former if mixed former never
replace smokingstatus=3 if smoking_c==3 & ad_stat==1 & smokingstatus==.	// former if mixed former never

replace smokingstatus=3 if smoking_c==1 & ad_stat==5 & smokingstatus==.	// former if mixed ever never
replace smokingstatus=3 if smoking_c==5 & ad_stat==1 & smokingstatus==.	// former if mixed ever never

replace smokingstatus=ad_stat if smoking_c==5 & ad_stat!=5 & smokingstatus==.	// current/former if mixed ever current/former
replace smokingstatus=smoking_c if smoking_c!=5 & ad_stat==5 & smokingstatus==.	// current/former if mixed ever current/former

replace smokingstatus=smoking_c if smokingstatus==.	// remaining conflicts: use Read coded





**# Single record per day
* rank: F > C > E > N > NC
gen order=.
replace order=1 if smokingstatus==3
replace order=2 if smokingstatus==4
replace order=3 if smokingstatus==5
replace order=4 if smokingstatus==1
replace order=5 if smokingstatus==2

bys patid date (order): keep if _n==1



**# Longitudinal record
keep patid date smokingstatus
sort patid date

*** First smoking record
gen tag=date if smokingstat>1
by patid: egen firstrec=min(tag)
drop tag
format firstrec %dD/N/CY

*** Never -> former if after first smoking record
replace smokingstat=3 if smokingstat==1 & date>=firstrec

*** Evers: set to previous record
by patid: replace smokingstat=smokingstat[_n-1] if smokingstat==5 & _n>1

*** Remaining evers (where ever is first record): set to current
replace smokingstat=4 if smokingstat==5



**# Most recent record on/before index
frlink m:1 patid, frame(cohort)
frget index, from(cohort)
drop if date > index
bys patid (date): keep if _n==_N



**# Link back to cohort file and save
sort patid
frame change cohort
frlink m:1 patid, frame(default)
frget smokingstatus, from(default)
keep patid smokingstatus

sort patid

recode smokingstatus (1=1) (3=2) (4=3)
label define smokingstatus 1 "Never" 2 "Former" 3 "Current"
label values smokingstatus smokingstatus

save data/prepared/`cohort'/bl_smoking.dta, replace


***
capture log close smoking
frames reset
clear
exit






/* NOTE - this is a modified version of the software SmokingDefinition v1.3 available from Zenodo.org. Original software by Arthritis Research UK Centre for Epidemiology, University of Manchester (2016-2018).
* The original code is available here: https://doi.org/10.5281/zenodo.793392
* The original code is shared under a CC-BY-NC-ND licence (https://creativecommons.org/licenses/by-nc-nd/4.0/).
*/
