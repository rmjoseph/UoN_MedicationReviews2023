** Created 2022-04-06 by Rebecca Joseph, University of Nottingham
*************************************
* Name:	scripts_masterfile.do
* Creator:	RMJ
* Date:	20220406	
* Desc:	Captures all data processing scripts in correct sequence
* Notes: 
* Version History:
*	Date	Reference	Update
* 20220406	new file	create file
* 20220627	scripts_masterfile	Import & save over65s product and common_dosages
* 20220830	scripts_masterfile	Reorder so smoking is after drug data cleaning
* 20221013	scripts_masterfile	Update to polypharm counts v2
* 20230111	scripts_masterfile	Change prep_Q2_dataset to v2
* 20230125	scripts_masterfile	Change whichdrugs to v3
* 20230125	scripts_masterfile	Add whichdrugs for all meds (incs non-repeats)
* 20230127	scripts_masterfile	Remove whichdrugs for all meds
* 20230130	scripts_masterfile	Update versions for analysis Q2 and Q3
* 20230131	scripts_masterfile	Update versions for analysis Q1
* 20230302	scripts_masterfile	Tidy script
* 20230313	scripts_masterfile	Add additional analysis files
*************************************

** log
capture log close masterfile
local date: display %dCYND date("`c(current_date)'", "DMY")
log using "logs/scripts_masterfile_`date'.txt", text append name(masterfile)
display "Running script sequence file; log opened $S_DATE $S_TIME"

** working directory 
cd "set working dir here"

** clear memory
set more off
frames reset


*************************************
**# PRELIM WORK (feasibility etc)
*do scripts/stata/prep_feasibility.do

**# Other required do-files called within scripts
*do scripts/stata/estdur.do
*do scripts/stata/test_estdur.do // used to error-check the estdur script

**# results checking
*do scripts/stata/analysis_Q2_linregchecks.do

**# Some AD preparation happened elsewhere (another project). The scripts below
**	ILLUSTRATE the process used but ARE NOT the original files.
*do scripts/stata/ad_linkageeligibility.do
*************************************



**# PREPARATION
*** same across both cohorts
do scripts/stata/prep_importcodelists.do	// import Read code lists, save lookup codelists_lookup.dta


*** COHORT 1: ANTIDEPRESSANTS
**** Import, define cohort, extract
do scripts/stata/prep_ad_importlookups.do	// import and save lookups (AND staff file)
do scripts/stata/prep_ad_definecohort.do	// cohort eligibility flag, index, followup dates, Townsend. Save ad_cohortfile.dta
do scripts/stata/prep_ad_extractmedical.do	// extract records from polypharm dataset based on medcode. Save ad_Clinical.dta etc.
do scripts/stata/prep_ad_extractadditional.do	// extract records from additional file. Save ad_Additional.dta
do scripts/stata/prep_ad_extractconstype.do	// extract consultation types & categorise. save ad/consultationtypes.dta
do scripts/stata/prep_extractethnicity.do	ad // ethnicity records (incs pre uts)

**** Define medication reviews
do scripts/stata/prep_define_medreviews.do	ad		// saves ad/medicationreviews.dta NOTE argument 'ad' needed
do scripts/stata/prep_timewindows.do		ad		// saves ad/timewindows_Q2_s NOTE argument 'ad' needed

**** Prescription data: clean/create lookups, import records
** Importing files
do scripts/stata/prep_import_dmdinfo.do	ad	// saves dmd_information.dta dmd_form_raw.dta
do scripts/stata/prep_import_bnfsnomedmap.do	ad	// saves bnfcodes.dta
do scripts/stata/prep_import_bnflabels.do	ad // saves bnfdescsfromopenpresc.dta
do scripts/stata/prep_lookup_dosageid.do	ad	// saves dosage_key.dta

** Defining formulation variables
do scripts/stata/prep_clean_goldformulation.do	ad // saves formulations_clean.dta
do scripts/stata/prep_clean_dmdformulation.do	ad // saves dmd_form_clean.dta
do scripts/stata/prep_clean_commondosages.do	ad // saves clean_dosages.dta

** Defining drug name and bnf chapter
do scripts/stata/prep_clean_drugname.do	ad // saves drugnames_clean.dta
do scripts/stata/prep_clean_bnfcode.do	ad // NB needs drugnames_clean.dta. saves bnfchapters_clean.dta

** Extracting records of interest from therapy files
do scripts/stata/prep_import_prescriptions.do	ad // saves raw/stata/ad_therapy_bnfchapter[1-14].dta

** Defining prescription length for all prescription records (requires estdur.do)
do scripts/stata/prep_clean_presclength.do	ad	// saves prepared/stata/ad/prescriptions_chapter[1-14].dta

** Define drug variables: which drugs before baseline, count at baseline, max count, which drugs
do scripts/stata/prep_drugsinwindows.do		ad		// saves datasets containing only records in the specified windows
do scripts/stata/prep_baselinedrugs.do	ad	//	saves baselinedrugs.dta
do scripts/stata/prep_numdrugsatbaseline.do	ad	//	saves numdrugsbaseline.dta
do scripts/stata/prep_polypharmacycount_v2.do	ad	// saves polypharmcounts.dta

**** Other variables 
do scripts/stata/prep_definecomorbs.do		ad		// saves ad/bl_comorbidities.dta. NOTE argument 'ad' needed
do scripts/stata/prep_defineethnicity_v2.do		ad		// saves ad/ethnicity.dta. NOTE argument 'ad' needed
do scripts/stata/prep_definebmi.do		ad		// saves ad/bl_bmi. NOTE argument 'ad' needed
do scripts/stata/prep_definealcohol.do		ad		// saves ad/bl_alcohol. NOTE argument 'ad' needed
do scripts/stata/prep_define_dyslipid.do		ad		// saves ad/bl_lipids. NOTE argument 'ad' needed
do scripts/stata/prep_define_smoking.do		ad		// saves ad/bl_smoking NOTE argument 'ad' needed
do scripts/stata/prep_definefrailty.do		ad		// saves ad/bl_frailty NOTE argument 'ad' needed
do scripts/stata/prep_define_fallsfractures.do		ad		// saves ad/bl_fallsfractures NOTE argument 'ad' needed

**** Combine to produce analysis-ready files (Q1, Q2)
do scripts/stata/prep_combinevars.do		ad		// saves ad/ad_prepared_dataset_Q1 NOTE argument 'ad' needed
do scripts/stata/prep_Q2_dataset_v2.do		ad		// saves ad/ad_prepared_dataset_Q2 NOTE argument 'ad' needed
do scripts/stata/prep_whichdrugs_v3.do	ad	// saves ad_prepared_dataset_Q3.dta




*** COHORT 2: OVER 65s
**** IMPORT SOME FILES ****
clear
import delim using "data/raw/over65s/extract_20220523/medrev_Extract_Staff_001.txt", stringcol(1)
save "data/raw/stata/over65s_Staff.dta", replace

clear
import delim using "data/raw/Lookups_2022_05/product.txt", stringcol(2)
save "data/raw/stata/over65s_product.dta", replace

clear
import delim using "data/raw/Lookups_2022_05/common_dosages.txt", stringcol(2)
save "data/raw/stata/over65s_common_dosages.dta", replace
****

**** Import, define cohort, extract
do scripts/stata/prep_over65s_patientlist.do	// generate lists of people to include in data extraction & linkage requests
do scripts/stata/prep_over65s_definecohort.do	// cohort eligibility flag, index, followup dates, Townsend. Save over65s_cohortfile.dta
do scripts/stata/prep_over65s_extractmedical.do	// extract records from polypharm dataset based on medcode. Save over65s_Clinical.dta etc.
do scripts/stata/prep_over65s_extractadditional.do	// extract records from additional file. Save over65s_Additional.dta
do scripts/stata/prep_over65s_extractconstype.do	// extract consultation types & categorise. save over65s/consultationtypes.dta
do scripts/stata/prep_extractethnicity.do	over65s // ethnicity records (incs pre uts)


**** Define medication reviews
do scripts/stata/prep_define_medreviews.do	over65s		// saves over65s/medicationreviews.dta NOTE argument 'over65s' needed
do scripts/stata/prep_timewindows.do		over65s		// saves over65s/timewindows_Q2 NOTE argument 'over65s' needed


**** Prescription data: clean/create lookups, import records
** Importing files
do scripts/stata/prep_import_dmdinfo.do	over65s	// saves dmd_information.dta dmd_form_raw.dta
do scripts/stata/prep_import_bnfsnomedmap.do	over65s	// saves bnfcodes.dta
do scripts/stata/prep_import_bnflabels.do	over65s // saves bnfdescsfromopenpresc.dta
do scripts/stata/prep_lookup_dosageid.do	over65s	// saves dosage_key.dta

** Defining formulation variables
do scripts/stata/prep_clean_goldformulation.do	over65s // saves formulations_clean.dta
do scripts/stata/prep_clean_dmdformulation.do	over65s // saves dmd_form_clean.dta
do scripts/stata/prep_clean_commondosages.do	over65s // saves clean_dosages.dta

** Defining drug name and bnf chapter
do scripts/stata/prep_clean_drugname.do	over65s // saves drugnames_clean.dta
do scripts/stata/prep_clean_bnfcode.do	over65s // NB needs drugnames_clean.dta. saves bnfchapters_clean.dta

** Extracting records of interest from therapy files
do scripts/stata/prep_import_prescriptions.do	over65s // saves raw/stata/over65s_therapy_bnfchapter[1-14].dta

** Defining prescription length for all prescription records (requires estdur.do)
do scripts/stata/prep_clean_presclength.do	over65s	// saves prepared/stata/over65s/prescriptions_chapter[1-14].dta

** Define drug variables: which drugs before baseline, count at baseline, max count, which drugs
do scripts/stata/prep_drugsinwindows.do		over65s		// saves datasets containing only records in the specified windows
do scripts/stata/prep_baselinedrugs.do	over65s	//	saves baselinedrugs.dta
do scripts/stata/prep_numdrugsatbaseline.do	over65s	//	saves numdrugsbaseline.dta
do scripts/stata/prep_polypharmacycount_v2.do	over65s	// saves polypharmcounts.dta

**** Other variables
do scripts/stata/prep_definecomorbs.do		over65s		// saves over65s/bl_comorbidities.dta. NOTE argument 'over65s' needed
do scripts/stata/prep_defineethnicity_v2.do		over65s		// saves over65s/ethnicity.dta. NOTE argument 'over65s' needed
do scripts/stata/prep_definebmi.do		over65s		// saves over65s/bl_bmi. NOTE argument 'over65s' needed
do scripts/stata/prep_definealcohol.do		over65s		// saves over65s/bl_alcohol. NOTE argument 'over65s' needed
do scripts/stata/prep_define_dyslipid.do		over65s		// saves over65s/bl_lipids. NOTE argument 'over65s' needed
do scripts/stata/prep_define_smoking.do		over65s		// saves over65s/bl_smoking NOTE argument 'over65s' needed
do scripts/stata/prep_definefrailty.do		over65s		// saves over65s/bl_frailty NOTE argument 'over65s' needed
do scripts/stata/prep_define_fallsfractures.do		over65s		// saves over65s/bl_fallsfractures NOTE argument 'over65s' needed

**** Combine to produce analysis-ready files (Q1, Q2)
do scripts/stata/prep_combinevars.do		over65s		// saves over65s/over65s_prepared_dataset_Q1 NOTE argument 'over65s' needed
do scripts/stata/prep_Q2_dataset_v2.do		over65s		// saves over65s/over65s_prepared_dataset_Q2 NOTE argument 'over65s' needed
do scripts/stata/prep_whichdrugs_v3.do	over65s	// saves over65s_prepared_dataset_Q3.dta



**# ANALYSIS
do scripts/stata/analysis_followup.do ad
do scripts/stata/analysis_Q1_v2.do ad
do scripts/stata/analysis_Q2_v2.do ad
do scripts/stata/analysis_Q3_v2.do ad

do scripts/stata/analysis_followup.do over65s
do scripts/stata/analysis_Q1_v2.do over65s
do scripts/stata/analysis_Q2_v2.do over65s
do scripts/stata/analysis_Q2_linregchecks.do over65s
do scripts/stata/analysis_Q3_v2.do over65s

do scripts/stata/analysis_extra_drugexposurechart.do
do scripts/stata/analysis_extra_BJGP2023abs.do

do scripts/stata/analysis_Q1_additional.do ad
do scripts/stata/analysis_Q1_additional.do over65s
do scripts/stata/analysis_Q2_additional.do ad
do scripts/stata/analysis_Q2_additional.do over65s


*************************************
frames reset
capture log close masterfile
exit


