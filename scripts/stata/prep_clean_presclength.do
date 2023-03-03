** created by Rebecca Joseph, University of Nottingham, 28 June 2022
*************************************
* Name:	prep_clean_presclength.do
* Creator:	RMJ
* Date:	202206028	
* Desc:	Runs estdur.do on all prescription data.
* Notes: frameappend. Define arg 'cohort'.
* Version History:
*	Date	Reference	Update
* 20220627	new file	Create file
* 20220704	prep_clean_presclength	Only load presc records <5years bef index
*************************************

** RUN FROM MASTER FILE
args cohort
di "`cohort'"

** Log
capture log close runestdur
local date: display %dCYND date("`c(current_date)'", "DMY")
log using logs/test_estdur_all_`cohort'_`date'.txt, text replace name(runestdur)
frames reset

** Set up, inc. loading the estdur program
frames reset
set more off
do "scripts/stata/estdur.do"






**# Load all reference datasets into frames
frame create prodinfo
frame prodinfo {
	clear
	use prodcode dmdcode using "data/raw/stata/`cohort'_product.dta"
	merge 1:1 prodcode using "data/prepared/`cohort'/formulations_clean.dta", keep(3) nogen keepusing(gold_form_num)
	merge 1:1 prodcode using "data/prepared/`cohort'/drugnames_clean.dta", keep(3) nogen keepusing(drugname)
	merge 1:1 prodcode using "data/prepared/`cohort'/bnfchapters_clean.dta", keep(3) nogen keepusing(bnfcode bnfcode_num chapter section bnfdesc chaptdesc drop_bnf longbnf)
	
	merge m:1 dmdcode using "data/prepared/`cohort'/dmd_form_clean", keep(1 3) nogen keepusing(dmd_form_num)
	
	sort prodcode
	drop dmdcode
	order prodcode drugname gold_form_num dmd_form_num drop_bnf bnfcode_num bnfcode bnfdesc chapter chaptdesc
	
}

frame create doseinfo
frame doseinfo {
	clear
	use "data/prepared/`cohort'/clean_dosages.dta"
	
	merge 1:1 dosekey using "data/prepared/`cohort'/dosage_key.dta", keep(3) nogen keepusing(dosageid)
	merge 1:1 dosageid using "data/raw/stata/`cohort'_common_dosages.dta", keep(3) nogen
	
	sort dosekey
	drop dosageid
}







**# Run estdur for all prescription records of interest
**	Different decisions for certain drugs and for tablets v other formulations
**		Load the raw file
**		Use gold_form dmd_form and dose_form to define formulation
**		Drop records with drop_bnf==1
**		Run estdur for tablets (formulation==7) and other formulations (formulation!=7)

*** oral glucocorticoids
foreach C of numlist 1 3 6 10 {
	di "$S_DATE $S_TIME"
	di "`C'"
	*** Load raw prescription data file
	clear
	use patid eventdate consid prodcode staffid qty numdays numpacks packtype issueseq dosekey if eventdate>=date("01/01/2014","DMY")  using  "data/raw/stata/`cohort'_therapy_bnfchapter`C'"
	
	*** Get all formulation vars & drop_bnf indicator
	frlink m:1 prodcode, frame(prodinfo)
	frget gold_form_num dmd_form_num drop_bnf bnfcode_num bnfcode, from(prodinfo)

	frlink m:1 dosekey, frame(doseinfo)
	frget prn dose_form, from(doseinfo)
	
	*** Define formulation using the 3 vars
	gen formulation=gold_form
	replace formulation=dmd_form if dmd_form<. & (formulation==. | formulation==8 | formulation==9) 
	replace formulation=dose_form if dose_form<. & formulation==.
	label values formulation unitform

	drop gold_form_num dmd_form_num dose_form

	*** Keep only oral GC records (based on bnf code)
	keep if regexm(bnfcode,"010502|^0302|060302|100102")==1 & formulation==7
	drop bnfcode
	
	*** Drop records if drop_bnf==1
	drop if drop_bnf==1

	*** Break loop if no records
	count 
	if `r(N)'==0 {
		continue
	}
	
	*** Get dose information
	frget daily_dose dose_duration, from(doseinfo)
	drop prodinfo doseinfo

	*** run the drug prep code
	estdur if formulation==7, maxdur(365) maxdif(28) prndef(7) default(7) overlap(14) maxgap(14)
	
	*** save
	keep patid prodcode dosekey qty numdays issueseq formulation start stop summed_qty num_recs
	sort patid start prodcode 
	save "data/prepared/`cohort'/prescriptions_chapter`C'_gcs.dta", replace
}


*** antibiotics
*** Load raw prescription data file
di "$S_DATE $S_TIME"
di "`C'"
clear
use patid eventdate consid prodcode staffid qty numdays numpacks packtype issueseq dosekey if eventdate>=date("01/01/2014","DMY")  using  "data/raw/stata/`cohort'_therapy_bnfchapter5"

*** Get all formulation vars & drop_bnf indicator
frlink m:1 prodcode, frame(prodinfo)
frget gold_form_num dmd_form_num drop_bnf bnfcode_num bnfcode, from(prodinfo)

frlink m:1 dosekey, frame(doseinfo)
frget prn dose_form, from(doseinfo)

*** Define formulation using the 3 vars
gen formulation=gold_form
replace formulation=dmd_form if dmd_form<. & (formulation==. | formulation==8 | formulation==9) 
replace formulation=dose_form if dose_form<. & formulation==.
label values formulation unitform

drop gold_form_num dmd_form_num dose_form

*** Drop records if drop_bnf==1
drop if drop_bnf==1

*** Get dose information
frget daily_dose dose_duration, from(doseinfo)
drop prodinfo doseinfo
drop bnfcode

*** run the drug prep code
estdur if formulation==7, maxdur(365) maxdif(28) prndef(7) default(7) overlap(14) maxgap(14)
estdur if formulation!=7, dropqty maxdur(365) maxdif(28) prndef(7) default(7) overlap(14) maxgap(14)

*** save
keep patid prodcode dosekey qty numdays issueseq formulation start stop summed_qty num_recs
sort patid start prodcode 
save "data/prepared/`cohort'/prescriptions_chapter5.dta", replace
	
	

*** everything else
foreach C of numlist 1/4 6/14 {

	di "$S_DATE $S_TIME"
	di "`C'"
	
	*** Load raw prescription data file
	clear
	use patid eventdate consid prodcode staffid qty numdays numpacks packtype issueseq dosekey if eventdate>=date("01/01/2014","DMY")  using  "data/raw/stata/`cohort'_therapy_bnfchapter`C'"
	
	*** Get all formulation vars & drop_bnf indicator
	frlink m:1 prodcode, frame(prodinfo)
	frget gold_form_num dmd_form_num drop_bnf bnfcode_num bnfcode, from(prodinfo)

	frlink m:1 dosekey, frame(doseinfo)
	frget prn dose_form, from(doseinfo)
	
	*** Define formulation using the 3 vars
	gen formulation=gold_form
	replace formulation=dmd_form if dmd_form<. & (formulation==. | formulation==8 | formulation==9) 
	replace formulation=dose_form if dose_form<. & formulation==.
	label values formulation unitform

	drop gold_form_num dmd_form_num dose_form

	*** Drop records handled elsewhere (oral glucocorticoids)
	drop if regexm(bnfcode,"010502|^0302|060302|100102")==1 & formulation==7
	drop bnfcode
	
	*** Drop records if drop_bnf==1
	drop if drop_bnf==1
	
	*** Get dose information
	frget daily_dose dose_duration, from(doseinfo)
	drop prodinfo doseinfo
	
	*** Break loop if no records
	count 
	if `r(N)'==0 {
		continue
	}	
	
	*** run the drug prep code
	estdur if formulation==7, maxdur(365) maxdif(28) prndef(28) default(28) overlap(14) maxgap(14)
	estdur if formulation!=7, dropqty maxdur(365) maxdif(28) prndef(28) default(28) overlap(14) maxgap(14)
	
	*** save
	keep patid prodcode dosekey qty numdays issueseq formulation start stop summed_qty num_recs
	sort patid start prodcode 
	save "data/prepared/`cohort'/prescriptions_chapter`C'.dta", replace
}

di "$S_DATE $S_TIME"

log close runestdur

frames reset
exit

