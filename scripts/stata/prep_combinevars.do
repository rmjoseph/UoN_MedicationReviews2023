** Created 2022-06-01 by Rebecca Joseph, University of Nottingham
*************************************
* Name:	prep_combinevars.do
* Creator:	RMJ
* Date:	20220601	
* Desc:	Combines all the variables needed for the analysis
* Notes: frameappend. Define arg 'cohort'.
* Version History:
*	Date	Reference	Update
* 20220601	new file	Create file
* 20220831	prep_combinevars.do	combined frailty var
* 20220831	prep_combinevars.do	encode ethnicity var to numeric
* 20220831	prep_combinevars.do	Combined vars for coronaryhd bloodclots
* 20220831	prep_combinevars.do	Update order of vars
* 20220831	prep_combinevars.do	Merge in baseline drugs and count
* 20220905	prep_combinevars.do	Recode missing COT and staff role to 99
* 20220905	prep_combinevars.do	Recode missing ethnicity smoking townsend alcohol bmicat to 99
* 20220905	prep_combinevars.do	Update labels
* 20230103	prep_combinevars.do	Make exclusion var to easily restrict
* 20230103	prep_combinevars.do	Make agecat variable
* 20230111	prep_combinevars.do	Recode polypharm cat var so 20+ is top group
* 20230119	prep_combinevars.do	Bug fix - top age cat now 95 not 105
* 20230123	prep_combinevars.do New region var at country level
* 20230201	prep_combinevars.do	Update def region_country for ad cohort
* 20230223	prep_combinevars.do	enddate+0.5 for people with enddate=01 Jan 2019
* 20230223	prep_combinevars.do	Make exclude_s (though now==exclude after above)
* 20230302	prep_combinevars.do	Tidy script
*************************************

** NEED TO RUN THIS FROM THE MASTERFILE SO ARGUMENT 'COHORT' IS DEFINED
args cohort
di "`cohort'"


** Log
local date: display %dCYND date("`c(current_date)'", "DMY")
di `date'
local logname: display "prep_combine_`cohort'_"`date'
di "`logname'"

capture log close comb
log using "logs/`logname'.log", append name(comb)

** frames reset
frames reset
set more off

*****************************************


*** Demographics
use data/prepared/`cohort'/`cohort'_cohortfile.dta

keep if eligible==1 
keep patid index sex region ageatindex patfupend townsend

gen swfup = patfupend-index + 1
label var swfup "Total eligible followup (patfupend-index+1)"

if "`cohort'"=="ad" {
	gen pracid=substr(patid,-3,.)
}
if "`cohort'"=="over65s" {
	gen pracid=substr(patid,-5,.)
}
destring pracid, replace

recode townsend (.=99)


**** make agecat variable
egen agecat = cut(ageatindex), at(15(10)95 120) icodes
label define agecat	0 "18-24" ///
					1 "25-34" ///
					2 "35-44" ///
					3 "45-54" ///
					4 "55-64" ///
					5 "65-74" ///
					6 "75-84" ///
					7 "85-94" ///
					8 "95+"
label values agecat agecat
label variable agecat "Age group"


**** Collapse region into country-level
if "`cohort'"=="over65s" {
	gen region_country=1 if region==11
	replace region_country=2 if region==10
	replace region_country=3 if region==12
	replace region_country=4 if region==7
	replace region_country=5 if region_country==.
	tab region region_country
	}
if "`cohort'"=="ad" {
	gen region_country=1 if region==12
	replace region_country=2 if region==13
	replace region_country=3 if region==11
	replace region_country=4 if region==9
	replace region_country=5 if region_country==.
	tab region region_country
	}

label define country 1 "Scotland" 2 "Wales" 3 "Northern Ireland" 4 "London" 5 "Rest of England"
label values region_country country
order region_country, after(region)
label var region_country "Practice region"




*** Ethnicity
merge 1:1 patid using data/prepared/`cohort'/ethnicity
drop _merge

rename ethnicity temp
encode temp, gen(ethnicity)
drop temp

order ethnicity, after(agecat)

recode ethnicity (.=99)


*** Medication reviews
merge 1:1 patid using data/prepared/`cohort'/medicationreviews
drop _merge

egen enddate = rowmin(patfupend firstrev_date)
egen enddate_s = rowmin(patfupend firstrev_date_s)
format enddate* %dD/N/CY
label var enddate "Earliest of cprd end, studywindow end, or first review"
label var enddate_s "Earliest of cprd end, studywindow end, or first review (sensitivity)"

gen reviewrate = (numreviews / swfup) * 365.25
gen reviewrate_s = (numreviews_s / swfup) * 365.25
label var reviewrate "Number of reviews during follow-up/years follow-up length"
label var reviewrate_s "Number of reviews during follow-up/years follow-up length (sensitivity)"

order patid pracid index patfupend enddate* swfup ///
	medreview* firstrev_type* firstrev_staff* firstrev_cot* reviewrate* numreviews* ///
	ageatindex sex ethnicity townsend region priormedrev* 
	
recode firstrev_cot* firstrev_staff* (.=99)


*** smoking alcohol bmi
merge 1:1 patid using data/prepared/`cohort'/bl_smoking
drop _merge
merge 1:1 patid using data/prepared/`cohort'/bl_alcohol
drop _merge
merge 1:1 patid using data/prepared/`cohort'/bl_bmi
drop _merge

recode smokingstatus alcoholintake bmicat (.=99)


*** frailty, lipids, comorbidities
merge 1:1 patid using data/prepared/`cohort'/bl_frailty
drop _merge
merge 1:1 patid using data/prepared/`cohort'/bl_lipids
drop _merge
merge 1:1 patid using data/prepared/`cohort'/bl_comorbidities
drop _merge
merge 1:1 patid using data/prepared/`cohort'/bl_fallsfractures
drop _merge


*** Frailty combined def
gen frailfallsfract=(frailtyrec==1|falls==1|fractures==1)
label var frailfallsfract "Severe frailty, or recent fall or fracture"

*** Dyslipid combined def
gen combined_dyslipid=(hyperlipid==1 | dyslipid==1 | famhypchol==1)
label var combined_dyslipid "hyperlipidaemia test result or dyslipid/familial hyperchol code"

*** Coronaryhd
gen chd=(coronaryhd==1|mi==1)
label var chd "coronary heart disease inc angina & MI"

*** blood clots
gen bloodclots=(thrombophilia==1 | thrombosis==1)

*** ORDER
order smokingstatus alcoholintake bmicat carehome ///
	atrialfib cancer chronkid copd chd dementia depression ///
	anxiety diabetes epilepsy heartfail hypertension hypothyroidism ///
	learningdis mentalhealth obesity osteoporosis palliative periphart ///
	rheumatoidarth stroketia asthma combined_dyslipid gout glaucoma ///
	parkinsons prostate urinarycont mobility bloodclots frailfallsfract ///
	hyperlipidaemia dyslipid famhypchol thrombophilia thrombosis ///
	frailtyrec falls fractures coronaryhd mi, after(priormedrev_s)


	
*** Baseline drugs
merge 1:1 patid using data/prepared/`cohort'/baselinedrugs.dta
drop _merge

merge 1:1 patid using data/prepared/`cohort'/numdrugsbaseline.dta
drop _merge
order  d_* b_* numdrugsbl* polypharm*, after(frailfallsfract)

**** REPLACE polypharm cat so 20+ is max group
replace polypharm=6 if polypharm>6 & polypharm<.
replace polypharm_noprn=6 if polypharm_noprn>6 & polypharm_noprn<.


**** Baseline drugs if cohort==ad --> drop antidep and bnf4 indicators
if "`cohort'"=="ad" {
	drop d_antidep
	drop b_bnf4
}




*** Create exclusion flag (added 20230103)
**** (20230223) if enddate==01 Jan 2019, keep by adding .5
replace enddate=enddate + 0.5 if enddate==date("01/01/2019","DMY")
replace enddate_s=enddate_s + 0.5 if enddate_s==date("01/01/2019","DMY")
****
gen exclude = (sex==. | enddate==index | polypharm==0)
label var exclude "Drop if exclude==1 (no sex, follow-up, or bl meds)"

gen exclude_s = (sex==. | enddate_s==index | polypharm==0)
label var exclude_s "(sensitivity) Drop if exclude==1 (no sex, follow-up, or bl meds)"
order exclude exclude_s, first

*** Update labels
label var sex "Sex"
label var ethnicity "Ethnicity"
label var smokingstatus "Smoking status"
label var alcoholintake "Alcohol intake"
label var bmicat "BMI category"

foreach X of varlist d_* b_* {
	local name = substr("`X'",3,.)
	label var `X' "Baseline `name'"
}

label define townsend 1 "Quintile 1 (least deprived)" 2 "Quintile 2" 3 "Quintile 3" 4 "Quintile 4" 5 "Quintile 5" 99 "Missing"
label values townsend townsend
label define ethnicity 99 "Missing", add
label define constype 99 "Missing", add
label define staffrole 99 "Missing", add
label define smokingstatus 99 "Missing", add
label define alcohol 99 "Missing", add
label define bmi 99 "Missing", add

label define presabs 0 "Absent" 1 "Present"
label define yesno 0 "No" 1 "Yes"

*label define polypharm 0 "0" 1 "1" 2 "2-4" 3 "5-9" 4 "10-14" 5 "15-19" 6 "20-24" 7 "25+" 8 "50+", modify
label define polypharm 0 "0" 1 "1" 2 "2-4" 3 "5-9" 4 "10-14" 5 "15-19" 6 "20+", modify
label values polypharm* polypharm

label values atrialfib-b_bnf99 yesno
label values carehome priormedrev* yesno



*** save
save data/prepared/`cohort'/`cohort'_prepared_dataset_Q1.dta, replace


*****************************************
frames reset
capture log close comb
exit


