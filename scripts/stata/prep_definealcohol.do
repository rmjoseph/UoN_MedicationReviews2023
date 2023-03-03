** CREATED 2022-05-31 by RMJ at the University of Nottingham
*************************************
* Name:	define_alcoholuse
* Creator:	RMJ
* Date:	20220531
* Desc:	Finds most recent alcohol status prior to index
* Requires: Stata 16+ for frames function; index date
* Version History:
*	Date	Reference	Update
*	20220531	[polypharmacy]/define_alcoholuse	Adapt for this analysis
*************************************

/* DEFINITION: Most recent status prior to index date. 
*  CLEANING APPLIED:
*		- If multiple records per day, pick one with highest alcohol use status
*		- Make non- former if there was a previous record of drinking
*/

** NEED TO RUN THIS FROM THE MASTERFILE SO ARGUMENT 'COHORT' IS DEFINED
args cohort
di "`cohort'"

set more off
frames reset
clear

**# Load cohort file, get index date and follow-up end date. 
capture frame create cohort
frame cohort {
	clear
	use data/prepared/`cohort'/`cohort'_cohortfile.dta
	keep if eligible==1
	keep patid index 
	sort patid
}

**# Load codelist lookup file
capture frame create codes
frame codes {
	clear
	use if alcohol==1 using data/prepared/`cohort'/codelists_lookup.dta
	sort medcode
	keep medcode desc alcohol_c

}

**# Get alcohol records from clinical referral and test files
capture frame create load
foreach X of newlist Clinical Referral Test {
	
	frame load {
		clear
		use patid date medcode using data/raw/stata/`cohort'_`X'.dta
		rename date eventdate
		
		frlink m:1 medcode, frame(codes)
		keep if codes<. 
		drop codes
		
		count
	}

	 if `r(N)'!=0 {
	 	frameappend load
	}

}


frlink m:1 medcode, frame(codes)
keep if codes<. 
frget *, from(codes)
drop codes

gen alcoholintake = .
replace alcoholintake = 1 if alcohol_c=="nondrinker"
replace alcoholintake = 2 if alcohol_c=="former"
replace alcoholintake = 3 if alcohol_c=="occasional"
replace alcoholintake = 4 if alcohol_c=="moderate"
replace alcoholintake = 5 if alcohol_c=="heavy"

label def alcohol 1 "non-" 2 "former" 3 "occasional" 4 "moderate" 5 "heavy"
label values alcoholintake alcohol



**# PROCESS THE RECORDS
** Drop if AFTER index date
frlink m:1 patid, frame(cohort)
frget index, from(cohort)
keep if cohort<.
drop cohort

drop if eventdate > index


** More than one record per day: pick highest code
bys patid eventdate (alcoholintake): keep if _n==_N

** First record of drinking anything
bys patid (eventdate): gen drinkrec=(alcoholin>1)
bys patid drinkrec (eventdate): gen firstdrink=eventdate[1] if drinkrec==1
format firstdrink %dD/N/CY
bys patid (firstdrink): replace firstdrink=firstdrink[1]

** Replace nondrinkers (1) with former drinkers(2) if ever had a prior drinking rec
sort patid eventdate
replace alcoholintake=2 if alcoholintake==1 & eventdate>=firstdrink

** Tidy
drop medcode drinkrec firstdrink



** KEEP MOST RECENT RECORD
bys patid (eventdate): keep if _n==_N


*** TIDY AND SAVE
keep patid alcoholintake

frame change cohort
keep patid
frlink 1:1 patid, frame(default)
frget *, from(default)
drop default
sort patid

save data/prepared/`cohort'/bl_alcohol.dta, replace




frames reset
clear
exit

