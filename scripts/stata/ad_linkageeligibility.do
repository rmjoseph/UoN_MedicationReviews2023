** Created 2023-03-02 by Rebecca Joseph, University of Nottingham
*************************************
* Name:	ad_linkageeligibility.do
* Creator:	RMJ
* Date:	20201027(original) 20230302 (current)
* Desc:	Outputs list of patients to request linked data for (ad dataset)
*	NOTE - NOT ORIGINAL FILE AND NOT USED IN ANALYSIS (recreates process MINUS
*	the 2015 eligibility patient list).
* Requires: Stata 16 (Frames function)
* Version History:
*	Date	Reference	Update
*	20230302	[polypharmacy]/linkage_eligibility_gold	Change paths & refer only to 2019
*************************************

/* Process:
// Load CPRD denominator files (patient, practice)
// Keep acceptable patients
// Load linkage_eligibility
// Combine patients and linkage_eligibility: keep if linked
// Keep if patient eligible for HES and ONS - THIS IS SOURCE POPn
// Split into two frames; repeat following for 2019 and 2015
//		Keep if follow-up starts on/bef 31/12/2019 and ends on/aft 01/01/2019
//		Keep if 18 in or before 2019
//		Keep if in the relevant define results
*/


frames reset


** LOG
capture log close linkgold
local date: display %dCYND date("`c(current_date)'", "DMY")
log using "logs/ad_linkage_`date'.txt", text append name(linkgold)


**** CREATE SOURCE POPULATION:
frame create source
frame change source
frame drop default

** Load patient data; keep acceptable permanently registered patients
import delim using data/raw/202011_Denom/all_patients_NOV2020.txt
keep if accept==1
count
drop if regstat==99
count
sort patid

** Load linkage eligibility file; merge; keep if in both files
frame create linkage
frame linkage {
	import delim using data/raw/202011_Denom/linkage_eligibility.txt
	sort patid
	}

frlink 1:1 patid, frame(linkage)
keep if linkage<.
count

** Keep if eligible for HES and ONS linkage
frget hes_e death_e, from(linkage)
drop linkage
keep if hes_e==1 & death_e==1
count // source file


****** Keep patients with antidep prescription in 2015 or 2019
** (define results - all pats 18+ years old and 1+ year of UTS followup before first ad in that year)
frame create ad2019
frame ad2019 {
	import delim using data/raw/ad/g_ad2019_Define_results.txt
	}
frlink 1:1 patid, frame(ad2019)
replace ad2019 = (ad2019<.)

count if ad2019==1


** Keep eligible patients and drop duplicates
keep ad2019==1
keep patid
duplicates drop
count

** Export
export delimited using "gold/data/prepared_text/20_000059_UniNottingham_patientlist_gold.txt", delim(tab) replace


**************************************
frames reset
capture log close linkgold
exit
**************************************

