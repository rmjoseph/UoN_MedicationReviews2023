* Created 2023-01-19 by Rebecca Joseph, University of Nottingham
*************************************
* Name:	analysis_Q2_linregchecks.do
* Creator:	RMJ
* Date:	20230119	
* Desc: Examining linear regression assumptions for over65s
* Notes: frameappend, tvc_split. Define arg 'cohort'.
* Version History:
*	Date	Reference	Update
* 20230119	analysis_Q2_linregchecks new file
*************************************


frames reset
use data/prepared/over65s/over65s_prepared_dataset_Q2.dta, clear

keep if elig1==1 & analysis==1 & counttype==1
drop if sex==.
drop if medreview!=1
count

keep patid pracid before elig1 medreview dif age* sex region* townsend ethnicity blpoly cot staffrole 

label list
misstable sum

*** DROP PATS WITH EXTREME VALUES
drop if before==0 // 0 meds before review
sum dif,d
keep if (dif >= r(mean) - 3*r(sd)) & (dif <= r(mean) + 3*r(sd)) 		

sum dif,d
count


/* Vars:
outcome: dif
covars: agecat sex blpoly region cot staffrole townsend 
other: ethnicity (not included)
*/

/* models:
fvset base 2 region
fvset base 5 ethnicity
fvset base 2 staffrole
fvset base 1 cot
fvset base 5 agecat
fvset base 3 blpoly	

regress dif, vce(cluster pracid)
regress dif i.agecat i.sex, vce(cluster pracid) 
regress dif i.agecat i.sex i.blpoly, vce(cluster pracid) 
regress dif i.agecat i.sex i.blpoly i.region i.cot i.staffrole, vce(cluster pracid) 
regress dif i.agecat i.sex i.blpoly i.region i.cot`i.staffrole i.townsend, vce(cluster pracid)
*/

scatter dif ageatindex


fvset base 2 region
fvset base 5 ethnicity
fvset base 2 staffrole
fvset base 1 cot
fvset base 5 agecat
fvset base 3 blpoly	

regress dif, vce(cluster pracid)
regress dif i.agecat i.sex
rvfplot, yline(0)

predict r, rstudent
scatter r dif
 
regress dif i.agecat i.sex i.blpoly, vce(cluster pracid) 
regress dif i.agecat i.sex i.blpoly i.region i.cot i.staffrole, vce(cluster pracid) 
regress dif i.agecat i.sex i.blpoly i.region i.cot i.staffrole i.townsend, vce(cluster pracid)

rvfplot, yline(0)

ologit dif


histogram dif, by(blpoly)



bys agecat: regress dif i.blpoly
bys sex: regress dif i.blpoly
bys sex: regress dif i.agecat

** Testing for interactions
foreach VAR1 of varlist agecat sex ethnicity townsend {
	foreach VAR2 of varlist agecat sex ethnicity townsend staffrole cot blpoly region_country {
		di "`VAR1' vs `VAR2'"
		if "`VAR1'"!="`VAR2'"   regress dif i.`VAR1'##i.`VAR2'
	}
}

foreach VAR1 of varlist staffrole cot blpoly region2 {
	foreach VAR2 of varlist agecat sex ethnicity townsend staffrole cot blpoly region_country {
		di "`VAR1' vs `VAR2'"
		if "`VAR1'"!="`VAR2'"   regress dif i.`VAR1'##i.`VAR2'
	}
}

/* possible interactions:
age#blpoly
sex#blpoly
age#cot? (other sig)

townsend#region
role#townsend
role#region
*/



regress dif i.sex i.agecat
anova dif i.sex i.agecat


histogram dif, by(agecat)
histogram dif, by(sex)
histogram dif, by(ethnicity)
histogram dif, by(townsend)
histogram dif, by(blpoly)		// group 1 skewed?
histogram dif, by(region)
histogram dif, by(region2)

histogram dif, by(cot)
histogram dif, by(staffrole)



regress dif i.agecat i.sex i.blpoly i.region i.cot i.staffrole i.townsend
regress dif i.agecat i.sex i.blpoly i.region i.cot i.staffrole i.townsend, vce(cluster pracid)

regress dif i.sex
regress dif i.sex, vce(cluster pracid)
meglm dif i.sex || pracid:
meglm dif i.sex || pracid: || region_country:



