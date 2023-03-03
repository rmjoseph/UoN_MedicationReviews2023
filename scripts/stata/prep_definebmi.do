** CREATED 2022-05-31 by RMJ at the University of Nottingham
*************************************
* Name:	prep_definebmi.do
* Creator:	RMJ
* Date: 20220531
* Desc:	Defines BMI using additional data
* Requires: Stata 16+ for frames function; index date
* Version History:
*	Date	Reference	Update
*	20220531	[polypharmacy]/define_bmi	adapt file for this analysis
*	20230302	prep_definebmi	Tidy script
*************************************

/* DEFINITION - MOST RECENT BMI ON OR BEFORE BASELINE
* Calculate using weight and height records
* Data cleaning steps:
*	- drop any records prior to age 18
*	- drop any height and weight records smaller than normal baby measurements and larger than largest known measurement (3-635kg and 0.45-2.72m)
*	- weight range 35 to 400
*	- height range 0.9 to 2.72
*	- drop patients with more than 15cm difference in their min and max height measurements
*	- use median height as a measure of patient height
*	- bmi lower limit 15, upper limit 63
*/

** NEED TO RUN THIS FROM THE MASTERFILE SO ARGUMENT 'COHORT' IS DEFINED
args cohort
di "`cohort'"

set more off
frames reset
clear



*** LOAD ADDITIONAL FILE, KEEP ENTTYPES FOR HEIGHT AND WEIGHT
use data/raw/stata/`cohort'_Additional.dta
keep if enttype==13 | enttype==14
sort patid adid


*** Merge with clinical file to get dates
capture frame create clinical
frame clinical {
	use patid date adid using data/raw/stata/`cohort'_Clinical.dta
	drop if adid=="0"
	duplicates drop
	rename date eventdate
	sort patid adid
}

frlink 1:1 patid adid, frame(clinical)
keep if clinical<.
frget *, from(clinical)
drop clinical

sort patid eventdate
drop data2 data4-data7

destring data1, replace
destring data3, replace


*** LOAD COHORT FILE TO GET DATE OF BIRTH; merge back into default
capture frame create patient
frame patient {
	clear
	use data/prepared/`cohort'/`cohort'_cohortfile.dta
	keep if eligible==1
	keep patid index patfupend yob uts
	sort patid
}

frlink m:1 patid, frame(patient)
frget *, from(patient)
keep if patient < .
drop patient


** Drop records prior to age 18; keep records after uts (already screened?)
keep if year(eventdate) - yob >= 18
count

keep if eventdate>=uts


*** SEND HEIGHT AND WEIGHT DATA INTO THEIR OWN FRAMES
frame put if enttype==13, into(weight) // put weight data in new frame
frame put if enttype==14, into(height) // put height data in new frame



*** IN NEW FRAME, CLEAN WEIGHT
frame change weight
keep patid data1 eventdate
rename data1 weightrec

drop if weightrec<=0 // drop if 0 or negative (assume error)
sum weightrec,d
di r(mean) + 3*r(sd)
di r(mean) - 3*r(sd)

drop if weightrec > 635 // drop if weight > heaviest person
drop if weightrec < 3	// small baby weight

sum weightrec,d
di r(mean) + 3*r(sd)
di r(mean) - 3*r(sd)

drop if weight < 35
drop if weight > 400



*** IN NEW FRAME, CLEAN HEIGHT
** NOTE: BMI tailored to 'normal' range of weights and heights. Reasonable to drop low heights. Use 4 foot (1.2m).
frame change height

keep patid eventdate data1
rename data1 heightrec

drop if heightrec<=0 // drop if 0 or negative (assume error)
sum heightrec,d
di r(mean) + 3*r(sd)
di r(mean) - 3*r(sd)

drop if heightrec > 2.72 // drop if height > tallest person ever
drop if heightrec < 0.45	// normal baby height

sum heightrec,d
di r(mean) + 3*r(sd)
di r(mean) - 3*r(sd)

drop if height < 0.9


*** Calculate average height per patient
bys patid: egen maxheight = max(heightrec)
bys patid: egen minheight = min(heightrec)
bys patid: gen heightdif = maxheight - minheight

bys patid: egen medianheight = median(heightrec)
bys patid: egen meanheight = mean(heightrec)

bys patid (eventdate): keep if _n==_N

drop if heightdif >= 0.15 // drop if change in height more than 15cm
keep patid medianheight // use median height as measure




*** COMBINE WEIGHT AND HEIGHT, AND CALCULATE BMI
frame change weight
frlink m:1 patid, frame(height)
frget *,from(height)

keep if height<.
drop height

gen bmi = weight / (medianheight*medianheight)


sum bmi,d
di r(mean) + 3*r(sd)
di r(mean) - 3*r(sd)

*** VERY LOW BMI is now almost entirely due to low weight tall height (perhaps entered as stone?). 15 is ~ 0.1%
drop if bmi < 15

*** VERY HIGH BMI: often high weight small height (but not always). 63 is ~0.1%
drop if bmi > 63





*** NOW KEEP MOST RECENT UP TO OR INCLUDING THE INDEX DATE
frlink m:1 patid, frame(patient)
frget index, from(patient)
drop patient

count
keep if eventdate <= index
count

bys patid (eventdate): keep if _n==_N
count


*** BMI category
gen bmicat = 1 if bmi <18.5
replace bmicat = 2 if bmi>=18.5 & bmi<25
replace bmicat = 3 if bmi>=25 & bmi<30
replace bmicat = 4 if bmi>=30 & bmi<35
replace bmicat = 5 if bmi>=35 & bmi<40
replace bmicat = 6 if bmi>=40

label define bmi	1 "underweight" ///
					2 "healthy" ///
					3 "overweight" ///
					4 "obese class 1" ///
					5 "obese class 2" ///
					6 "obese class 3+"
					
label values bmicat bmi
tab bmicat


*** TIDY AND SAVE
frame change patient
keep patid
frlink 1:1 patid, frame(weight)
frget bmi*, from(weight)

keep patid bmi bmicat
sort patid

save data/prepared/`cohort'/bl_bmi.dta, replace





frames reset
clear
exit

