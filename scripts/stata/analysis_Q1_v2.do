* Created 31 Jan 2023 by Rebecca Joseph, University of Nottingham
*************************************
* Name:	analysis_Q1_v2.do
* Creator:	RMJ
* Date:	20230131	
* Desc: Commands to produce results for analysis Q1
* Notes: frameappend, tvc_split. Define arg 'cohort'.
* Version History:
*	Date	Reference	Update
* 20220722	analysis_MQ2022Abs.do	Update & allow both cohorts
* 20220905	analysis_Q1	No longer need to merge bldrugs etc or encode ethnicity
* 20220905	analysis_Q1	Extra counts and update tab1 so not split by medreview
* 20220906	analysis_Q1	Draw graphs showing %with medication review
* 20221003	analysis_Q1	Update collect style so vars all have 1dp
* 20221020	analysis_Q1	Finalise putdocx commands for descriptive part of analysis
* 20221021	analysis_Q1	Add putdocx commands for stcox
* 20221021	analysis_Q1	Add a local macro to exclude townsend from ad stcox
* 20230103	analysis_Q1	Change order of exclusions so no follow-up bef no bl prescs
* 20230103	analysis_Q1	Update tables for table 1 (include split by review y/n)
* 20230131	analysis_Q1	New version (_v2)
* 20230131	analysis_Q1_v2	Remove ageatindex and add agecat to regression
* 20230131	analysis_Q1_v2	Replace region with region_country in models
* 20230131	analysis_Q1_v2	Add loop to output multiple adjusted models
* 20230201	analysis_Q1_v2	Fix bug where final table repeated `mod1'
* 20230201	analysis_Q1_v2	Add region_country to baseline charas table
* 20230222	analysis_Q1_v2	Change order of exclusions (no follow-up before sex)
* 20230222	analysis_Q1_v2	Cut section doing study population counts (moved - new file)
* 20230223	analysis_Q1_v2	Add first putdocx steps (title of page) back in
* 20230302	analysis_Q1_v2	Tidy script
*************************************

** NEED TO RUN THIS FROM THE MASTERFILE SO ARGUMENT 'COHORT' IS DEFINED
args cohort
di "`cohort'"

***
frames reset
set scheme cleanplots

** log
capture log close q1
local date: display %dCYND date("`c(current_date)'", "DMY")
log using "logs/`cohort'_results_Q1_`date'.txt", text replace name(q1)



**## WORD DOC ##**
capture putdocx clear
putdocx begin

putdocx paragraph, style(Title)
putdocx text ("Results for analysis question 1")
putdocx paragraph






*** Restart and use exclude flag to restrict
use data/prepared/`cohort'/`cohort'_prepared_dataset_Q1.dta, clear

drop if exclude==1
count


**# - Summarise characteristics of people at cohort entry 
*** check distribn of vars
histogram ageatindex
sum ageatindex, d

histogram bmi
sum bmi,d


*** Table containing median (IQR) age, for people with/without reviews and overall
table (var) (medreview), stat(median ageatindex) stat(q1 ageatindex) stat(q3 ageatindex)
collect composite define IQR = q1 q3, delimiter(", ") 	// make result showing "q1, q2"
collect style cell result[IQR], nformat(%2.0f) sformat("(%s)")	// format as "(q1, q2)"
collect composite define mediqr = median IQR, delimiter(" ") // result showing "median (q1, q2)"
collect style cell border_block, border(right, pattern(nil))
collect style cell, font(,size(9))

collect layout (result[mediqr]) (medreview)
collect style putdocx, layout(autofitcontents)

*******
*putdocx pagebreak
putdocx paragraph
putdocx text ("Table. Median (interquartile range) age in 2019")
putdocx paragraph
putdocx collect
*******



*** Table containing all categorical vars
local varlist1 carehome-b_bnf99
unab varlist1: `varlist1'
di "`varlist1'"

table (var) (medreview), ///
	stat(fvfrequency agecat sex ethnicity townsend region region_country smokingstatus alcoholintake ///
	bmicat 1.(`varlist1') polypharm polypharm_noprn 1.(priormedrev priormedrev_s)) ///
	stat(fvpercent agecat sex ethnicity townsend region region_country smokingstatus alcoholintake ///
	bmicat 1.(`varlist1') polypharm polypharm_noprn 1.(priormedrev priormedrev_s))

collect recode result 	fvfrequency = count	///
						fvpercent   = percent

collect style cell result[count], nformat(%9.0fc)
collect style cell result[percent], nformat(%4.1fc) sformat("(%s%%)")
collect composite define countperc = count percent, delimiter(" ") 

collect layout (var#result[countperc]) (medreview)

collect style row split
collect style cell border_block, border(right, pattern(nil))

collect preview
collect style putdocx, layout(autofitcontents)


*******
putdocx pagebreak
putdocx paragraph
putdocx text ("Table. Baseline characteristics wrt 01 Jan 2019")
putdocx paragraph
putdocx collect
******




*** Open loop to run on main analysis and sensitivity analysis
forval S=1/2 {
	collect clear
	local s
	if `S'==2	local s "_s"

	**# Crude rates
	* - Number of people who have a medication review
	* - Rate of people having medication review.

	stset enddate`s', fail(medreview`s') origin(index) enter(index) id(patid) scale(365) 

	collect: stptime
	collect style cell result[failures], nformat(%9.0fc) 
	collect style cell result[ptime], nformat(%9.0fc) 
	collect style cell result[rate], nformat(%4.3f) 
	collect composite define myci= lb ub, delimiter(", ")
	collect style cell result[myci], nformat(%4.3f) sformat("(%s)")
	collect composite define rateci = rate myci, delimiter(" ")

	collect layout (var) (result[failures ptime rateci])
	collect style putdocx, layout(autofitcontents)

	*******
	putdocx pagebreak
	putdocx paragraph
	putdocx text ("Table. Crude rate of medication reviews in 2019")
	if `S'==2	putdocx text (" - SENSITIVITY")
	putdocx paragraph
	putdocx collect
	******

	qui sts graph
	graph export outputs/q1_`cohort'_survival`s'.tif, replace

	********
	putdocx pagebreak
	putdocx paragraph
	putdocx text ("Figure. Survival curve, time to medication review")
	if `S'==2	putdocx text (" - SENSITIVITY")
	putdocx paragraph
	putdocx image outputs/q1_`cohort'_survival`s'.tif
	*******


	**# Consultation types, staff roles, numbers of reviews
	table (var) (), ///
		stat(fvfrequency 1.(medreview`s')) ///
		stat(fvpercent 1.(medreview`s')) 
		
	table (var) () if medreview`s'==1, ///
		stat(fvfrequency 1.numreviews`s' firstrev_cot`s' firstrev_staffrole`s') ///
		stat(fvpercent 1.numreviews`s' firstrev_cot`s' firstrev_staffrole`s') append

	collect recode result 	fvfrequency = count	///
							fvpercent   = percent

	collect layout (var) (result[count percent])
	collect style cell var[]#result[count], nformat(%9.0fc) // COUNT
	collect style cell var[]#result[percent], nformat(%9.1fc) sformat("%s%%") // PERCENTAGE
	collect style row stack, nobinder spacer
	collect style cell border_block, border(right, pattern(nil))

	collect preview
	collect style putdocx, layout(autofitcontents)


	*******
	putdocx pagebreak
	putdocx paragraph
	putdocx text ("Table. Information about medication reviews")
	if `S'==2	putdocx text (" - SENSITIVITY")
	putdocx paragraph
	putdocx collect
	******


	**# When were the reviews
	gen month`s'=month(firstrev_date`s')
	qui graph bar (percent), over(month`s')

	graph export outputs/q1_`cohort'bar_reviewmonth`s'.tif, replace

	********
	putdocx pagebreak
	putdocx paragraph
	putdocx text ("Figure. Bar chart showing month in which review was recorded")
	if `S'==2	putdocx text (" - SENSITIVITY")
	putdocx paragraph
	putdocx image outputs/q1_`cohort'bar_reviewmonth`s'.tif
	*******


		
	** end of loop
}
		




**# COX REGRESSION
* - (Characteristics of people with/without reviews)
* - Cox regression comparing characteristics of people with/without reviews (test PH assumption)
/******* MODEL CHECKS
stset enddate, fail(medreview) origin(index) enter(index) id(patid) scale(365) 

order priormedrev_s, last

fvset base 5 ethnicity
fvset base 2 region
fvset base 3 alcoholintake
fvset base 2 bmicat

stcox ageatindex, schoenfeld(sch*) scaledsch(sca*)
stphtest, plot(ageatindex)
graph export outputs/`cohort'_phtest_age.tif, replace
estat phtest
// although the phtest is sig, the graph is horizontal. Assume ok.

local vars "ethnicity-frailfallsfract d_* b_* polypharm"
stcox ageatindex i.sex i.(`vars')
estat phtest, d

local vars "ethnicity-frailfallsfract d_* b_* polypharm"
stcox ageatindex i.sex i.(`vars') if firstrev_date!=index
estat phtest, d

stphplot if firstrev_date!=index, by(ethnicity) plot1(msym(none)) plot2(msym(none)) plot3(msym(none)) plot4(msym(none)) plot5(msym(none)) plot6(msym(none))
stcoxkm, by(ethnicity) obsopts(msymbol(none)) predopts(msymbol(none))

stcoxkm, by(townsend) obsopts(msymbol(none)) predopts(msymbol(none))
stcoxkm, by(polypharm) obsopts(msymbol(none)) predopts(msymbol(none))

stcoxkm, by(region) obsopts(msymbol(none)) predopts(msymbol(none))

stphplot if firstrev_date!=index, by(priormedrev) plot1(msym(none)) plot2(msym(none)) 
stphplot if firstrev_date!=index, by(smoking) plot1(msym(none)) plot2(msym(none))  plot3(msym(none)) plot4(msym(none))
stphplot if firstrev_date!=index, by(alcoholintake) plot1(msym(none)) plot2(msym(none))  plot3(msym(none)) plot4(msym(none)) plot5(msym(none))
stphplot if firstrev_date!=index, by(carehome) plot1(msym(none)) plot2(msym(none)) 
stphplot if firstrev_date!=index, by(copd) plot1(msym(none)) plot2(msym(none)) 
stphplot if firstrev_date!=index, by(dementia) plot1(msym(none)) plot2(msym(none)) 
stphplot if firstrev_date!=index, by(depression) plot1(msym(none)) plot2(msym(none)) 
stphplot if firstrev_date!=index, by(diabetes) plot1(msym(none)) plot2(msym(none)) 
stphplot if firstrev_date!=index, by(rheumatoid) plot1(msym(none)) plot2(msym(none)) 
stphplot if firstrev_date!=index, by(mobility) plot1(msym(none)) plot2(msym(none)) 
stphplot if firstrev_date!=index, by(d_antipsych) plot1(msym(none)) plot2(msym(none)) 
stphplot if firstrev_date!=index, by(d_benzo) plot1(msym(none)) plot2(msym(none)) 

// possible issue with region (Y&tH) but other variables look fine
**********************/

gen c_age10 = (ageatindex - 65)/10

** Loop for normal and strict definition of medreviews
forval S=1/2 {
	collect clear
	local s
	if `S'==2	local s "_s"
	
	** Local to exclude townsend if cohort is ad
	local townsend
	if "`cohort'"=="over65s"	local townsend townsend
	

	**# Models
	stset enddate`s', fail(medreview`s') origin(index) enter(index) id(patid) scale(365) 
	fvset base 5 ethnicity
	fvset base 2 region
	fvset base 3 alcoholintake
	fvset base 2 bmicat

	order priormedrev_s, last



	**** Unadjusted
	local vars "agecat sex `townsend' region_country polypharm priormedrev`s' carehome atrialfib-frailfallsfract d_* b_*"
	unab vars : `vars'
	di "`vars'"

	** Open first collection
	collect clear
	collect create c1
	collect, name(c1): stcox c_age10, vce(cluster pracid)

	** Copy to new combined collection (these steps probably can be combiend)
	collect create cX
	collect combine cX = cX c1, replace

	** Over each categ var, collect stcox results and add to combined collection
	foreach V of local vars {
		collect create c2, replace
		collect, name(c2): stcox i.`V', vce(cluster pracid)

		collect combine cX = cX c2, replace
	}

	** Set row type to split (which normally looks like: Var Level)
	collect style row split 

	** Turn off base
	collect style showbase off

	** Specify how variables appear in table 
	** (age as is, sex & cat vars by label, other binary vars by name)
	foreach V of varlist priormedrev`s' carehome atrialfib-frailfallsfract d_* b_* {
		collect style header `V', title(name)
		collect style header `V', level(hide)
	}

	** Make composite var for HR (CI), p-value
	collect style cell result [_r_b], nformat(%5.2f)
	collect style cell result [_r_p], nformat(%5.3f)
	collect composite define myci= _r_lb _r_ub, delimiter(", ")
	collect style cell result[myci], nformat(%9.2f) sformat("(%s)")
	collect composite define coeff= _r_b myci, trim override
	collect composite define coeff2= coeff _r_p, delimiter(", p=")	

	** Turn off label for column header
	collect style header result[coeff2], title(name)
	collect style header result[coeff2], level(hide)

	** Turn off vertical grid line and specify font size
	collect style cell border_block, border(right, pattern(nil))
	collect style cell, font(,size(9))

	** Specify layout
	collect layout (colname[c_age10] `vars') (result[coeff2])

	** Save output to word doc
	collect style putdocx, layout(autofitcontents) 

	*******
	putdocx paragraph
	putdocx text ("Table. Unadjusted Cox regression results for medication reviews")
	if `S'==2	putdocx text (" - SENSITIVITY")
	putdocx paragraph
	putdocx collect
	*******






	**** Age-sex adjusted part 1 (do age sex model first, then collect results from all)
	collect clear
	collect: stcox i.agecat i.sex, vce(cluster pracid)

	** Set row type to split (which normally looks like: Var Level)
	collect style row split 

	** Turn off base
	collect style showbase off

	** Make composite var for HR (CI), p-value
	collect style cell result [_r_b], nformat(%5.2f)
	collect style cell result [_r_p], nformat(%5.3f)
	collect composite define myci= _r_lb _r_ub, delimiter(", ")
	collect style cell result[myci], nformat(%9.2f) sformat("(%s)")
	collect composite define coeff= _r_b myci, trim override
	collect composite define coeff2= coeff _r_p, delimiter(", p=")	

	** Turn off label for column header
	collect style header result[coeff2], title(name)
	collect style header result[coeff2], level(hide)

	** Turn off vertical grid line and specify font size
	collect style cell border_block, border(right, pattern(nil))
	collect style cell, font(,size(9))

	** Specify layout
	collect layout (colname[agecat] sex) (result[coeff2])

	** Save output to word doc
	collect style putdocx, layout(autofitcontents) 

	*******
	putdocx paragraph
	putdocx text ("Table. Age-sex model, Cox regression")
	if `S'==2	putdocx text (" - SENSITIVITY")
	putdocx paragraph
	putdocx collect
	*******





	**** Age-sex adjusted part 2 (do age sex model first, then collect results from all)
	local vars2 "region_country polypharm priormedrev`s' carehome atrialfib-frailfallsfract d_* b_*"

	unab vars2 : `vars2'
	di "`vars2'"

	collect clear
	collect create cX
	collect, name(cX): stcox i.agecat i.sex i.townsend, vce(cluster pracid)

	** Over each categ var, collect stcox results and add to combined collection
	foreach V of local vars2 {
		collect create c2, replace
		collect, name(c2): stcox i.agecat i.sex i.`V', vce(cluster pracid)

		collect combine cX = cX c2, replace
	}

	** Set row type to split (which normally looks like: Var Level)
	collect style row split 

	** Turn off base
	collect style showbase off

	** Make composite var for HR (CI), p-value
	collect style cell result [_r_b], nformat(%5.2f)
	collect style cell result [_r_p], nformat(%5.3f)
	collect composite define myci= _r_lb _r_ub, delimiter(", ")
	collect style cell result[myci], nformat(%9.2f) sformat("(%s)")
	collect composite define coeff= _r_b myci, trim override
	collect composite define coeff2= coeff _r_p, delimiter(", p=")	

	** Turn off label for column header
	collect style header result[coeff2], title(name)
	collect style header result[coeff2], level(hide)

	** Specify how variables appear in table 
	** (age as is, sex & cat vars by label, other binary vars by name)
	foreach V of varlist priormedrev`s' carehome atrialfib-frailfallsfract d_* b_* {
		collect style header `V', title(name)
		collect style header `V', level(hide)
	}

	** Turn off vertical grid line and specify font size
	collect style cell border_block, border(right, pattern(nil))
	collect style cell, font(,size(9))

	** Specify layout
	collect layout (`townsend' `vars2') (result[coeff2])

	** Save output to word doc
	collect style putdocx, layout(autofitcontents) 

	*******
	putdocx paragraph
	putdocx text ("Table. Age-sex adjusted vars, Cox regression")
	if `S'==2	putdocx text (" - SENSITIVITY")
	putdocx paragraph
	putdocx collect
	*******






	**** Full model
	local mod1 priormedrev`s' carehome
	local mod2 `mod1' atrialfib-frailfallsfract
	local mod3 `mod1' d_*
	local mod4 `mod1' b_*
	local mod5 `mod1' atrialfib-frailfallsfract d_*

	unab mod1 : `mod1'
	unab mod2 : `mod2'
	unab mod3 : `mod3'
	unab mod4 : `mod4'
	unab mod5 : `mod5'

	local name1 "Adjusted for demographic characteristics, polypharmacy, prior med reviews, and living in a care home"
	local name2 "Adjusted for demographic characteristics, polypharmacy, prior med reviews, and living in a care home plus comorbidities"
	local name3 "Adjusted for demographic characteristics, polypharmacy, prior med reviews, and living in a care home plus named medicines"
	local name4 "Adjusted for demographic characteristics, polypharmacy, prior med reviews, and living in a care home plus baseline medicines by BNF chapter"
	local name5 "Adjusted for demographic characteristics, polypharmacy, prior med reviews, and living in a care home plus comorbidities and named medicines"

	
	forval MOD=1/5 {	// Loop over 5 different adjusted models
		
		collect clear
		collect: stcox i.(agecat sex `townsend' region_country polypharm `mod`MOD''), vce(cluster pracid)

		** Set row type to split (which normally looks like: Var Level)
		collect style row split 

		** Turn off base
		collect style showbase off

		** Make composite var for HR (CI), p-value
		collect style cell result [_r_b], nformat(%5.2f)
		collect style cell result [_r_p], nformat(%5.3f)
		collect composite define myci= _r_lb _r_ub, delimiter(", ")
		collect style cell result[myci], nformat(%9.2f) sformat("(%s)")
		collect composite define coeff= _r_b myci, trim override
		collect composite define coeff2= coeff _r_p, delimiter(", p=")	

		** Turn off label for column header
		collect style header result[coeff2], title(name)
		collect style header result[coeff2], level(hide)

		** Specify how variables appear in table 
		** (sex & cat vars by label, other binary vars by name)
		foreach V of local mod`MOD' {
			collect style header `V', title(name)
			collect style header `V', level(hide)
		}

		** Turn off vertical grid line and specify font size
		collect style cell border_block, border(right, pattern(nil))
		collect style cell, font(,size(9))

		** Specify layout
		collect layout (agecat sex `townsend' region_country polypharm `mod`MOD'') (result[coeff2])

		** Save output to word doc
		collect style putdocx, layout(autofitcontents) 

		*******
		putdocx paragraph
		putdocx text ("Table. `name`MOD''")
		if `S'==2	putdocx text (" - SENSITIVITY")
		putdocx paragraph
		putdocx collect
		*******
	} // looping over different adjusted models

}  // sensitivity

local date: display %dCYND date("`c(current_date)'", "DMY")
putdocx save "outputs/Q1Results_`cohort'_`date'.docx", replace


********************
collect clear
frames reset
capture log close q1 
exit


