** Created by Rebecca Joseph, University of Nottingham, 15 June 2022
*************************************
* Name:	clean_goldformulation.do
* Creator:	RMJ
* Date:	20220615	
* Desc: Define updated & simplified classification of drug formulation based on
*		CPRD GOLD lookup product.dta and linked DMD info from TRUD.
* Notes:
* Version History:
*	Date	Reference	Update
* 20220615	clean_drugdictionary_gold	Separate out the formulation section as new file
* 20220620	clean_goldformulation	Cut the sections linking with the DMD info (move elsewhere)
* 20220622	clean_goldformulation	Update file paths with macros
* 20220627	clean_goldformulation	Adapt for medication review project
* 20220822	prep_clean_goldformulation	Edit so various inhalation devices are classed as inhaled
* 20220822	prep_clean_goldformulation	Remove section defining newform as var not used
* 20220702	prep_clean_goldformulation	Remove ROUTE section
* 20230302	prep_clean_goldformulation	Tidy script
*************************************

** NEED TO RUN THIS FROM THE MASTERFILE
args cohort
di "`cohort'"
**

frames reset

use "data/raw/stata/`cohort'_product.dta"

keep prodcode formulation 



**# Get categorised formulations for GOLD dict
frame create FORM
frame FORM: import excel "data/raw/codelists/GOLD_RoutesFormulations_v2.xlsx", sheet(GoldForm) firstrow
frlink m:1 formulation, frame(FORM)
frget new_form, from(FORM)
drop FORM
frame drop FORM

rename new_form gold_form


**# Combine the three sources of formulation info
replace gold_form = "" if gold_form=="unspec"
replace gold_form = "unknown" if gold_form==""
replace gold_form = "nondrug" if regexm(gold_form,"device|food" )==1


**# tidy & make numeric version
keep prodcode gold_form 

gen gold_form_num=.
replace gold_form_num=1 if gold_form=="drops"
replace gold_form_num=2 if gold_form=="spray"
replace gold_form_num=3 if gold_form=="inhaled"
replace gold_form_num=4 if gold_form=="injected"
replace gold_form_num=5 if gold_form=="creams/topical"
replace gold_form_num=6 if gold_form=="patches"
replace gold_form_num=7 if gold_form=="tablets"
replace gold_form_num=8 if gold_form=="unspec liquid"
replace gold_form_num=9 if gold_form=="other"
replace gold_form_num=10 if gold_form=="nondrug"

label define unitform 1 "drops" 2 "spray" 3 "inhaled" 4 "injected" 5 "creams/topical" 6 "patches" 7 "tablets" 8 "unspec liquid" 9 "other" 10 "non-drug" , modify

label values gold_form_num unitform



**# save output
sort prodcode
save "data/prepared/`cohort'/formulations_clean.dta", replace

frames reset
exit

