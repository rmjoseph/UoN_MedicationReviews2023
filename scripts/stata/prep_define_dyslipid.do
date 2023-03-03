** Created 2022-05-31 by Rebecca Joseph, University of Nottingham
*************************************
* Name:	prep_define_dyslipid.do
* Creator:	RMJ
* Date:	2022-05-31	
* Desc:	Ever RAISED blood lipids at baseline
* Notes: Needs Stata v16+
* Version History:
*	Date	Reference	Update
* 20220531	new file	create file
* 20230302	prep_define_dyslipid	Tidy script
*************************************


** NEED TO RUN THIS FROM THE MASTERFILE SO ARGUMENT 'COHORT' IS DEFINED
args cohort
di "`cohort'"

set more off
frames reset
clear

**# Load cohort file to get index date and patient list
frame create cohort
frame cohort {
	clear
	use data/prepared/`cohort'/`cohort'_cohortfile.dta
	keep if eligible==1
	keep patid index
	sort patid
}



**# Lipid test results
/*
enttype	description
163	Serum cholesterol
175	High density lipoprotein
177	Low density lipoprotein
202	Triglycerides
206	Very low density lipoprotein
214	Blood lipids
363	Lipoprotein electrophoresis
*/
capture frame create lipids

frame change lipids
clear
use data/raw/stata/`cohort'_Test.dta
keep patid date medcode enttype data*


merge m:1 medcode using data/prepared/`cohort'/codelists_lookup.dta, keepusing(lipidtests lipidtests_c desc)
drop if _merge==2
drop _merge

keep if lipidtests==1 | enttype==163|enttype==175|enttype==177|enttype==202| ///
		enttype==206|enttype==214|enttype==363 


*** LDL cholesterol
frame put if lipidtests_c=="LDL" | enttype==177, into(LDL)
frame LDL {
	
	rename data2 value
	destring value, replace
	
	rename data5 rangefrom
	destring rangefrom, replace
	
	rename data6 rangeto
	destring rangeto, replace

	sum value, d
	drop if value<=0
	drop if value==.
	
	sum value,d
	di `r(mean)' + 3*`r(sd)'
	di `r(p75)' + 1.5*(`r(p75)' - `r(p25)')
	di `r(p75)' + 3*(`r(p75)' - `r(p25)')
	di `r(p25)' - 1.5*(`r(p75)' - `r(p25)')
	
	drop if value>`r(p75)' + 3*(`r(p75)' - `r(p25)')
	
	keep patid date value lipidtests_c
	
	gen raised = (value > 4.1)
	
}


*** Triglycerides
frame change lipids
frame put if lipidtests_c=="TG" | enttype==202, into(TG)

frame TG {
	rename data2 value
	destring value, replace
	
	rename data5 rangefrom
	destring rangefrom, replace
	
	rename data6 rangeto
	destring rangeto, replace

	sum value, d
	drop if value<=0
	drop if value==.
	
	sum value, d
	di `r(mean)' + 3*`r(sd)'
	di `r(p75)' + 1.5*(`r(p75)' - `r(p25)')
	di `r(p75)' + 3*(`r(p75)' - `r(p25)')
	di `r(p75)' + 5*(`r(p75)' - `r(p25)')

	di `r(p25)' - 1.5*(`r(p75)' - `r(p25)')

	sum value, d
	drop if value>=5*(`r(p75)' - `r(p25)')	// q3+3*IQR is <99th percentile, and less than 'very high' ref range
	
	keep patid date value lipidtests_c
	
	gen raised = (value > 2.3)
	
}


*** Total cholesterol
frame change lipids
frame put if lipidtests_c=="total" , into(total)
frame total {
	
	drop if enttype==214 // enttype 214 doesn't have values
	
	rename data2 value
	destring value, replace
	
	rename data5 rangefrom
	destring rangefrom, replace
	
	rename data6 rangeto
	destring rangeto, replace
	
	sum value, d
	drop if value==.
	drop if value<=0

	sum value, d
	di `r(mean)' + 3*`r(sd)'
	di `r(p75)' + 1.5*(`r(p75)' - `r(p25)')
	di `r(p75)' + 3*(`r(p75)' - `r(p25)')	
	di `r(p25)' - 1.5*(`r(p75)' - `r(p25)')

	sum value, d
	drop if value > `r(p75)' + 3*(`r(p75)' - `r(p25)')

	keep patid date value lipidtests_c
	
	gen raised = (value > 6.5)

}


*** Remaining records
frame change lipids
keep if lipidtests==.
drop if enttype==163|enttype==175|enttype==177|enttype==202| ///
		enttype==206|enttype==214|enttype==363|enttype==202

count
// all accounted for

clear
frameappend total
frameappend TG
frameappend LDL

frlink m:1 patid, frame(cohort)
frget index, from(cohort)

drop if date > index
keep if raised == 1

keep patid raised
duplicates drop

rename raised hyperlipidaemia
label var hyperlipid "Blood test: raised tot cholesterol LDL-c or triglycerides on/bef index"



**# Merge with cohort and save
frame change cohort
keep patid
sort patid
frlink 1:1 patid, frame(lipids)
frget *, from(lipids)
drop lipids

replace hyperlipid=0 if hyperlipid==.



**# Save file
save data/prepared/`cohort'/bl_lipids.dta, replace



**# Close
frames reset
capture log close comorb
exit






