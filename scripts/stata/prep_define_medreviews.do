** Created 2022-04-30 by Rebecca Joseph, University of Nottingham
*************************************
* Name:	prep_define_medreviews.do
* Creator:	RMJ
* Date:	20220530	
* Desc:	Defines medication reviews (first, last, all) and types
* Notes: frameappend. Define arg 'cohort'.
* Version History:
*	Date	Reference	Update
* 20220530	new file	create file
* 20220531	prep_define_medreviews	replace var cprdend with patfupend
* 20220602	prep_define_medreviews	bug fix in test referral import section
* 20220905	prep_define_medreviews	update staffrole to combine 'other' from new grouping
* 20221005	prep_define_medreviews	Save dataset with all records for later checks
* 20230302	prep_define_medreviews	Tidy script
*************************************

** NEED TO RUN THIS FROM THE MASTERFILE SO ARGUMENT 'COHORT' IS DEFINED
args cohort
di "`cohort'"

** Log
local date: display %dCYND date("`c(current_date)'", "DMY")
di `date'
local logname: display "prep_frailty_`cohort'_"`date'
di "`logname'"

capture log close reviews
log using "logs/`logname'.log", append name(reviews)

**
frames reset
set more off



*****************
**# Load and prepare the different file types
** Load cohort file, get index date and follow-up end date. Make index-365 days.
capture frame create cohort
frame cohort {
	clear
	use data/prepared/`cohort'/`cohort'_cohortfile.dta
	keep if eligible==1
	keep patid index patfupend
	gen oneyearbef= index-365
	format oneyearbef %dD/N/CY
	sort patid
}



** Load codelist lookup file
capture frame create codes
frame codes {
	clear
	use if medrev==1 using data/prepared/`cohort'/codelists_lookup.dta
	sort medcode
	keep medcode desc medrev_c
	destring medrev_c, replace
	
	gen person=.
	replace person=2 if medcode==30435 // gp
	replace person=3 if medcode==19157 | medcode==104551 // nurse
	replace person=1 if medcode==12741 | medcode==102421 // pharmacist
	replace person=4 if medcode==69681 | medcode==102815 // other


}



** Clinical Referral Test, keep medrev records, drop if outside time window, append
*** Each file slightly different so do separately (i.e. not as loop)
capture frame create load

*** Clinical
frame load {
	clear
	use patid date medcode enttype adid consid staffid using data/raw/stata/`cohort'_Clinical.dta
	rename date eventdate
	
	frlink m:1 medcode, frame(codes)
	frget *, from(codes)
	keep if codes<. | enttype==461
	drop codes
	
	frlink m:1 patid, frame(cohort)
	frget *, from(cohort)
	drop if eventdate<oneyearbef
	drop if eventdate>patfupend
	
	count
	gen file="c" if `r(N)'!=0
}

frameappend load


*** Test
frame load {
	clear
	use patid date medcode enttype data* consid staffid using data/raw/stata/`cohort'_Test.dta
	rename date eventdate
	
	frlink m:1 medcode, frame(codes)
	frget *, from(codes)
	keep if codes<. | enttype==461
	drop codes
	
	frlink m:1 patid, frame(cohort)
	frget *, from(cohort)
	drop if eventdate<oneyearbef
	drop if eventdate>patfupend
	
	count
	gen file="t" if `r(N)'!=0
}

if `r(N)'!=0 {
	frameappend load
}


*** Referral
frame load {
	clear
	use patid date medcode consid staffid using data/raw/stata/`cohort'_Referral.dta
	rename date eventdate
	
	frlink m:1 medcode, frame(codes)
	frget *, from(codes)
	keep if codes<.
	drop codes
	
	frlink m:1 patid, frame(cohort)
	frget *, from(cohort)
	drop if eventdate<oneyearbef
	drop if eventdate>patfupend
	
	count
	gen file="r" if `r(N)'!=0
}

if `r(N)'!=0 {
	frameappend load
}




**# Staff roles
*** Load staff role lookup file
capture frame create staffrol
frame staffrol{
    clear
    import delim using data/raw/codelists/staffrole_v2.csv 
	sort role
}

*** Load staff file and merge with lookup file
capture frame create staff
frame staff {
    clear
    use data/raw/stata/`cohort'_Staff.dta
	sort role
	
	frlink m:1 role, frame(staffrol)
	frget *, from(staffrol)
	drop staffrol
	
	sort staffid
}

*** Merge staff role with extracted records
frlink m:1 staffid, frame(staff)
frget category, from(staff)
drop staff

*** Convert staff role info to numeric
gen staffrole=.
replace staffrole=1 if category=="pharmacist"
replace staffrole=2 if category=="GP"
replace staffrole=3 if category=="nurse"
replace staffrole=4 if category=="other"|category=="otherpatcare"
replace staffrole=5 if category=="admin"

label define staffrole 1 "pharmacist" 2 "GP" 3 "nurse" 4 "other" 5 "admin"
label values staffrole staffrole
drop category

replace staffrole=person if person<.




**# Consultation types
*** Merge with the prepared consultation types file
sort patid consid
merge m:1 patid consid using data/prepared/`cohort'/consultationtypes.dta, keepusing(cot)
drop if _merge==2
drop _merge
label define constype 1 "face to face" 2 "telephone" 3 "other"
label values cot constype





**# Create variables: prior reviews, review as outcome, review count, normal and sensitivity
** Any review in year before index
frame put if eventdate<index, into(prior)
frame prior {
	gen priormedrev=1
	
	gen temp=1 if (cot==1 | cot==2) & medrev_c==1
	bys patid: egen priormedrev_s = max(temp)
	
	keep patid priormedrev priormedrev_s
	duplicates drop
}




** First review (on/)after index 
drop if eventdate<index

**** SAVE a version of the extracted data at this point
frame put patid index patfupend eventdate staffrole cot medrev_c medcode desc, into(tosave)
frame tosave {
	rename desc desc_medrevlist
	merge m:1 medcode using data/raw/ad/medical.dta, keep(1 3) keepusing(readcode desc) nogen	// no over65s equiv
	order patid index patfupend eventdate staffrole cot medrev_c readcode medcode desc desc_medrevlist
	duplicates drop
	bys patid: egen firstrev = min(eventdate)
	format firstrev %dD/N/CY
	
	gen sensitivity = (cot==1|cot==2) & medrev_c==1
	
	save data/prepared/`cohort'/extractedreviews.dta, replace
}
frame drop tosave




*** Characteristics of first review: duplicate records on one date? Use sort to define:
*** - highest Read code strength
*** - highest consultation type (f2f > telephone > other)
*** - 'highest' staff role (pharmacist>GP>nurse>other>admin) (assumption that GP has oversight over changes made by other roles)
bys patid eventdate (cot): replace cot=cot[1]
bys patid eventdate (medrev_c): replace medrev_c=medrev_c[1]
bys patid eventdate (staffrole): replace staffrole=staffrole[1]

keep patid eventdate cot medrev_c staffrole
duplicates drop
duplicates report patid eventdate

*** Separate out the subset of reviews for sensitivity
frame put if (cot==1 | cot==2) & medrev_c==1, into(sensitivity)

*** Date of first review - all
bys patid: egen firstrev = min(eventdate)
frame put if firstrev==eventdate, into(outcome1)

frame outcome1 {
	drop firstrev

	rename eventdate firstrev_date
	rename staffrole firstrev_staffrole
	rename cot firstrev_cot
	rename medrev_c firstrev_type
	replace firstrev_type=(firstrev_type==1 & firstrev_cot<3)
}

*** Date of first review - sensitivity
frame sensitivity {

	bys patid: egen firstrev = min(eventdate)
	frame put if firstrev==eventdate, into(outcome2)

	frame outcome2 {
		drop firstrev medrev_c

		rename eventdate firstrev_date_s
		rename staffrole firstrev_staffrole_s
		rename cot firstrev_cot_s
	}

}


** All reviews - count and last date (main)
bys patid: egen lastreview=max(eventdate)
bys patid: gen numreviews=_N
keep patid lastreview numreviews
duplicates drop

*** All reviews - count and last date (sensitivity)
frame sensitivity {

	bys patid: egen lastreview_s=max(eventdate)
	bys patid: gen numreviews_s=_N
	keep patid lastreview numreviews
	duplicates drop

}




**# Combine all this info with the cohort file so have results for all pats
frame change cohort
keep patid

frlink m:1 patid, frame(prior)
frget *, from(prior)
replace priormedrev = (priormedrev==1)
replace priormedrev_s = (priormedrev_s==1)
label variable priormedrev "Indicator of medication review in year before index"
label variable priormedrev_s "Indicator of medication review in year before index (sensitivity)"
drop prior

frlink m:1 patid, frame(outcome1)
frget *, from(outcome1)
gen medreview=(outcome1<.)
drop outcome
order medreview, before(firstrev_date)
label var medreview "Indicator of medication review on/after index"
label var firstrev_date "Date of first medication review on/after index"
label var firstrev_staffrole "Staff role for first medication review on/after index"
label var firstrev_cot "Consultation type for first medication review on/after index"
label var firstrev_type "Indicator of 'strength' of first medication review record"

frlink m:1 patid, frame(outcome2)
frget *, from(outcome2)
gen medreview_s=(outcome2<.)
drop outcome2
order medreview_s, before(firstrev_date)
label var medreview_s "Indicator of medication review on/after index (sensitivity)"
label var firstrev_date_s "Date of first medication review on/after index (sensitivity)"
label var firstrev_staffrole_s "Staff role for first medication review on/after index (sensitivity)"
label var firstrev_cot_s "Consultation type for first medication review on/after index (sensitivity)"

frlink m:1 patid, frame(default)
frget *, from(default)
drop default
format lastreview %dD/N/CY
replace numreviews=0 if numreviews==.
label var lastreview "Date of last medication review during follow-up"
label var numreviews "Number of medication reviews (unique days) during follow-up"

frlink m:1 patid, frame(sensitivity)
frget *, from(sensitivity)
drop sensitivity
format lastreview_s %dD/N/CY
replace numreviews_s=0 if numreviews_s==.
label var lastreview_s "Date of last medication review during follow-up (sensitivity)"
label var numreviews_s "Number of medication reviwes (unique days) during follow-up (sensitivity)"

order patid priormedrev priormedrev_s medreview firstrev_date firstrev_staffrole firstrev_cot firstrev_type lastreview numreviews


**# Save and close
save data/prepared/`cohort'/medicationreviews.dta, replace




***********
frames reset
capture log close reviews
exit
