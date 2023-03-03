** Created by Rebecca Joseph, University of Nottingham, 05 Nov 2021
*************************************
* Name:lookup_dosageid.do
* Creator:	RMJ
* Date:	20211105	
* Desc: creates a numeric id to replace string dosageid variable
* Notes:
* Version History:
*	Date	Reference	Update
* 20211105	new file	create file
* 20220615	makelookup_dosageid	Rename file
* 20220622	lookup_dosageid	Update file paths with macros
* 20220627	lookup_dosageid	Adapt for medication reviews file
*************************************

** NEED TO RUN THIS FROM THE MASTERFILE
args cohort
di "`cohort'"
**


frames reset
use "data/raw/stata/`cohort'_common_dosages.dta"
keep dosageid
sort dosageid
duplicates report 

gen dosekey = _n

save "data/prepared/`cohort'/dosage_key.dta", replace

frames reset
exit
