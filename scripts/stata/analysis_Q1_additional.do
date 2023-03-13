* Created 10 Mar 2023 by Rebecca Joseph, University of Nottingham
*************************************
* Name:	analysis_Q1_additional.do
* Creator:	RMJ
* Date:	20230310	
* Desc: Extra analyses for question 1 (follow-up for medreview y/n)
* Notes: 
* Version History:
*	Date	Reference	Update
* 20230310	analysis_Q1_additional	File started
* 20230313	analysis_Q1_additional	Create report (log file)
*************************************

** NEED TO RUN THIS FROM THE MASTERFILE SO ARGUMENT 'COHORT' IS DEFINED
args cohort
di "`cohort'"

***
frames reset

** log
capture log close q1a
local date: display %dCYND date("`c(current_date)'", "DMY")
log using "outputs/`cohort'_Q1_additional_`date'.txt", text replace name(q1a)

** Start
use data/prepared/`cohort'/`cohort'_prepared_dataset_Q1.dta, clear

drop if exclude==1
count

replace patfupend=patfupend+0.5 if patfupend==index

gen fail=1
stset patfupend, failure(fail) id(patid) origin(index) enter(index) scale(365)



** PERSON-TIME FOR PEOPLE WHO DID/DIDN'T HAVE A MEDICATION REVIEW - 
** ... without censoring on review date (i.e. total CPRD follow-up in 2019)
stptime, by(medreview)

** NUMBER OF PEOPLE WITH FULL CPRD FOLLOW-UP IN 2019
gen fullfup = (swfup==365)
tab fullfup

** PROPN OF PEOPLE WHO HAD A MEDICATION REVIEW AMONG THOSE WITH FULL FOLLOW-UP
tab medreview if swfup==365,m


********************
collect clear
frames reset
capture log close q1a 
exit


