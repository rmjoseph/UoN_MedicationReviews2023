** Created 2022-11-07 by Rebecca Joseph, University of Nottingham
*************************************
* Name:	analysis_extra_BJGP2023abs.do
* Creator:	RMJ
* Date:	20221107	
* Desc:	Analysis results for BJGP 2023 abtract
* Notes: 
* Version History:
*	Date	Reference	Update
* 20221107	new file	create file
*************************************

**** Average change by polypharmacy count, over65s cohort, analysis1, results B
use patid sex medreview* using "data/prepared/over65s/over65s_prepared_dataset_Q1.dta", clear
rename sex sex_cohort

merge 1:1 patid using  "data/prepared/over65s/timewindows_Q2_s.dta", keepusing(elig*)
drop _merge
rename elig3 elig5
rename elig6 E6TEMP
rename elig4 elig7
rename elig1 elig8
drop eligible

merge 1:1 patid using  "data/prepared/over65s/timewindows_Q2.dta", keepusing(elig*)
drop _merge
rename elig1 TEMP
rename elig3 elig1
rename elig6 elig2
rename elig4 elig3
rename TEMP elig4
drop eligible

rename E6TEMP elig6

merge 1:m patid using "data/prepared/over65s/over65s_prepared_dataset_Q2.dta"
gen matched=(_merge==3)
drop _merge

drop if sex_cohort==.
drop if medreview==0
drop if elig1!=1
drop medreview*
drop elig*
drop matched

keep if analysis==1

reshape wide countA countB countC, i(patid) j(period)
foreach X of newlist A B C {
	gen dif`X' = count`X'1 - count`X'0
}
order patid countA0 countA1 origcountA difA  countB0 countB1 origcountB difB   countC0 countC1 origcountC difC

keep patid countB0-difB pracid
gen pre=countB0
gen post=countB1

egen blpoly = cut(origcount), at(0,1,2,5(5)25) icodes
label define polypharm 0 "0" 1 "1" 2 "2-4" 3 "5-9" 4 "10-14" ///
						5 "15-19" 6 "20-24" 7 "25+" 8 "50+", modify
label values blpoly polypharm
label variable blpoly "Polypharmacy count before review"

drop if origcount==0
sum dif,d
keep if (dif >= r(mean) - 3*r(sd)) & (dif <= r(mean) + 3*r(sd)) 

count

regress dif, vce(cluster pracid) 
regress dif if blpoly>=4, vce(cluster pracid) 




