* Created 2023-01-25 by RMJ, University of Nottingham
*************************************
* Name:	analysis_Q3_v2.do
* Creator:	RMJ
* Date:	20230125	
* Desc: Outputs a table showing most prescribed drugs before and after
* Notes: frameappend, define arg 'cohort'.
* Version History:
*	Date	Reference	Update
* 20220907	analysis_Q3_draft	First full draft, simplified for new dataset 
* 20220907	analysis_Q3_draft	Loop 1/8 rather than 6 
* 20221019	analysis_Q3_draft	Add in code for graphs
* 20221020	analysis_Q3_draft	Update tables to show stats for before/aft/both
* 20221024	analysis_Q3_draft	Tidy desc2 for table 
* 20230125	analysis_Q3_v2	Write program to make easier to tailor graphs
* 20230127	analysis_Q3_v2	Remove data cleaning code at start (moved)
* 20230127	analysis_Q3_v2	Update varnames to match new names
* 20230130	analysis_Q3_v2	Update (correct) definition of bycounts option
* 20230130	analysis_Q3_v2	Export main graph file as sep pdf and jpg
* 20230130	analysis_Q3_v2	Change table sort order and variable list
* 20230222	analysis_Q3_v2	Change labels for started/stopped
*************************************
** NEED TO RUN THIS FROM THE MASTERFILE SO ARGUMENT 'COHORT' IS DEFINED
*ssc install splitvallabels
*net install grc1leg, from("http://www.stata.com/users/vwiggins/")
*net install cleanplots, from("https://tdmize.github.io/data/cleanplots")

args cohort
di "`cohort'"
frames reset

set scheme cleanplots
** log
capture log close Q3
local date: display %dCYND date("`c(current_date)'", "DMY")
log using "logs/analysisQ3_`cohort'_`date'.txt", text replace name(Q3)


**# Open datasets
use data/prepared/`cohort'/`cohort'_prepared_dataset_Q3.dta, clear
frame put if allmeds==1, into(allmeds)
drop if allmeds==1





**# GRAPHS		
**** DEFINE PROGRAM	
capture program drop BAR
program define BAR

syntax [if] , FIGSORT(varname) RANKS(integer) [BYCOUNT TITLE(string) NAME(string)] 
if "`title'"!=""  local TITLE "title(`title', size(medsmall))"
if "`name'"!=""  local NAME "name(`name',replace)"

tempname GRAPH
capture frame drop `GRAPH'
frame pwf
frame copy `r(currentframe)' `GRAPH'

frame `GRAPH' {
	
	if "`if'"!="" keep `if'

	** Redo rankings based on data subset
	drop rank*
	gsort analysis type outcometype -total_pre
	by analysis type outcometype: gen rank_pre=_n

	gsort analysis type outcometype -total_post
	by analysis type outcometype: gen rank_post=_n

	gsort analysis type outcometype -count_onlypost
	by analysis type outcometype: gen rank_onlypost=_n

	gsort analysis type outcometype -count_onlypre
	by analysis type outcometype: gen rank_onlypre=_n
	
	** Keep specified number of records by rank
	if "`bycount'" == "" {
		keep if rank_onlypost<=`ranks' | rank_onlypre<=`ranks' 		
	}
	if "`bycount'" == "bycount" {
		keep if rank_post<=`ranks' | rank_pre<=`ranks' 
	}
	
	** Reshape long for bar graphs
	rename count_onlypre count1
	rename count_both count2
	rename count_onlypost count3
	keep desc2 d_* n_elig_pop count1 count2 count3  rank_* type

	reshape long count, i(desc2) j(N) 
	gen pc = 100*(count/n_elig_pop)
	format pc %5.1g
	format pc %5.1f

	** Vars needed for bar graphs
	separate pc, by(N)
	gen period=(N>2)

	** Tidy description for display
	replace desc2="Co-codamol" if desc2=="codeine + paracetamol"
	replace desc2=proper(desc2)
	encode desc2, gen(desc3)
	splitvallabels desc3, recode length(30) nobreak
		
	** Bar graph
	graph hbar  pc1  pc3 pc2, ///
				over(desc3, relabel(`r(relabel)') sort(`figsort') label(labsize(*0.5)) gap(*2))  ///
		legend(order(1 "Prescribed before only (stopped)" 2 "Prescribed after only (started)" ///
			3 "Prescribed before and after (continued)")  pos(6)) ///
		ytitle("% of study population") ///
		bar(1, color(0 58 109)) ///
		bar(2, color(17 146 232)) ///
		bar(3, color(186 230 255)) ///
		ysize(3.5) xsize(3) `TITLE' `NAME'

}
end			


**** MAKE GRAPHS

/* USING BAR:
provide subset using if
options:
figsort(varname)	the variable that determines the sort order of the bars
ranks(integer)		the number of results to show on the graph
[bycount]			include if ranking by  all before/after rather thanstopping/starting 
[name(string)]		name of the graph
[title(string)]		title of the graph
*/


*** MAIN GRAPH - PDF
frame put if analysis==1 & outcometype==1 & type==1  & form=="tablets", into(new)
frame new {
	replace desc2=desc3
	BAR if analysis==1 & outcometype==1 & type==1 & form=="tablets", figsort(rank_onlypost) ranks(20) name(MAIN)
	graph export outputs/Q3Bar_`cohort'_main.pdf, replace
	graph export outputs/Q3Bar_`cohort'_main.jpg, width(1200) quality(100) name(MAIN) replace
}


*** Graphs to go in word doc
*** Main, 3 results types 
BAR if analysis==1 & outcometype==1 & type==1 & form=="tablets", figsort(rank_onlypost) ranks(20) name(main1) 
BAR if analysis==1 & outcometype==1 & type==2,  figsort(rank_onlypost) ranks(20) name(main2)
BAR if analysis==1 & outcometype==1 & type==3, figsort(rank_onlypost) ranks(20) name(main3)

*** Sorted by most prescribed
BAR if analysis==1 & outcometype==1 & type==1 & form=="tablets", figsort(rank_post) ranks(20) name(main1tot) bycount
BAR if analysis==1 & outcometype==1 & type==2,  figsort(rank_post) ranks(20) name(main2tot) bycount
BAR if analysis==1 & outcometype==1 & type==3, figsort(rank_post) ranks(20) name(main3tot) bycount

*** All formulations
BAR if analysis==1 & outcometype==1 & type==1, figsort(rank_onlypost) ranks(20) name(allforms) 

*** Sensitivity analyses
forval A=1/4 {
	forval O=1/2 {
		BAR if analysis==`A' & outcometype==`O' & type==1 & form=="tablets", figsort(rank_onlypost) ranks(20) name(sens_`A'_`O') 
	} 
}

*** All meds (inc non-repeat) (EDITED - REMOVE outcometype==1)
frame allmeds {
	BAR if analysis==1 & type==1 & form=="tablets", figsort(rank_onlypost) ranks(20) name(allmedstabs) title("All prescription types (tablets only)")
	BAR if analysis==1 & type==1, figsort(rank_onlypost) ranks(20) name(allmedsallforms) title("All prescription types")
}

*** By BNF chapter
local chapters 01 02 03 04 05 06 07 08 09 10 11 12 13
foreach X of local chapters  {
	di "`X'"
	BAR if analysis==1 & outcometype==1 & type==1 & regexm(bnf,"`X'[0-9][0-9]")==1, figsort(rank_onlypost) ranks(15) name(chapter`X') title("BNF Chapter `X'")
}

*** For named meds
BAR if analysis==1 & outcometype==1 & type==1 & d_ach==1, figsort(rank_onlypost) ranks(20) name(antichol) title("Anticholinergic medicines")
BAR if analysis==1 & outcometype==1 & type==1 & d_opioid==1, figsort(rank_onlypost) ranks(20) name(opioids) title("Opioids") 
BAR if analysis==1 & outcometype==1 & type==1 & d_gaba==1, figsort(rank_onlypost) ranks(20) name(gabapent) title("Gabapentinoids")
BAR if analysis==1 & outcometype==1 & type==1 & d_psychotrop==1, figsort(rank_onlypost) ranks(20) name(psychotrop)  title("Psychotropic medicines")






**** OUTPUT GRAPHS
capture putdocx clear
putdocx begin

putdocx paragraph, style(Title)
putdocx text ("Analysis question 3 - bar charts")

putdocx textblock begin, paramode
This document includes bar charts showing the TOP 15 medicines prescribed before and after 
a medication review. Medicines are ranked according to how often they were CHANGED 
after the review (specifically, the number of times they were only prescribed AFTER 
the review).

Unless otherwise stated:

- these are medicines prescribed in the three months before and/or three months 
after a medication review. 

- Only medicines prescribed as a repeat prescription are shown.
putdocx textblock end

putdocx pagebreak


** Main results, including tablets v all formulations
putdocx paragraph, style(Heading1)
putdocx text ("Main analysis")

putdocx paragraph
putdocx text ("Figure 1. Medicines prescribed before and/or after a medication review ranked by most frequently 'started', drug-substance level (tablets only)"), linebreak bold
graph display main1
graph export outputs/Q3Bar_`cohort'_temp.jpg, width(1200) quality(100) name(main1) replace
putdocx image outputs/Q3Bar_`cohort'_temp.jpg, linebreak
putdocx pagebreak

putdocx paragraph
putdocx text ("Figure 2. Medicines prescribed before and/or after a medication review ranked by most frequently 'started', drug-substance level (all formulations)"), linebreak bold
graph display allforms
graph export outputs/Q3Bar_`cohort'_temp.jpg, width(1200) quality(100) name(allforms) replace
putdocx image outputs/Q3Bar_`cohort'_temp.jpg, linebreak
putdocx pagebreak

putdocx paragraph
putdocx text ("Figure 3. Medicines prescribed before and/or after a medication review ranked by most frequently 'started', BNF section level"), linebreak bold
graph display main2
graph export outputs/Q3Bar_`cohort'_temp.jpg, width(1200) quality(100) name(main2) replace
putdocx image outputs/Q3Bar_`cohort'_temp.jpg, linebreak
putdocx pagebreak

putdocx paragraph
putdocx text ("Figure 4. Medicines prescribed before and/or after a medication review ranked by most frequently 'started', BNF chapter level"), linebreak bold
graph display main3
graph export outputs/Q3Bar_`cohort'_temp.jpg, width(1200) quality(100) name(main3) replace
putdocx image outputs/Q3Bar_`cohort'_temp.jpg, linebreak
putdocx pagebreak



** All prescriptions including non-repeats
putdocx paragraph, style(Heading1)
putdocx text ("All prescriptions, including non-repeat prescriptions")

putdocx paragraph
putdocx text ("Figure 5. Medicines prescribed before and/or after a medication review ranked by most frequently 'started', drug-substance level (tablets only)"), linebreak bold
graph display allmedstabs
graph export outputs/Q3Bar_`cohort'_temp.jpg, width(1200) quality(100) name(allmedstabs) replace
putdocx image outputs/Q3Bar_`cohort'_temp.jpg, linebreak
putdocx pagebreak

putdocx paragraph
putdocx text ("Figure 6. Medicines prescribed before and/or after a medication review ranked by most frequently 'started', drug-substance level (all formulations)"), linebreak bold
graph display allmedsallforms
graph export outputs/Q3Bar_`cohort'_temp.jpg, width(1200) quality(100) name(allmedsallforms) replace
putdocx image outputs/Q3Bar_`cohort'_temp.jpg, linebreak
putdocx pagebreak


** By BNF chapter
putdocx paragraph, style(Heading1)
putdocx text ("Results by BNF chapter")

local counter 6
local chapters 01 02 03 04 05 06 07 08 09 10 11 12 13
foreach X of local chapters {
	local counter=`counter'+1
	*display `counter'

	putdocx paragraph
	putdocx text ("Figure `counter'. Medicines prescribed before and/or after a medication review ranked by most frequently 'started', BNF chapter `X'"), linebreak bold
	graph display chapter`X'
	graph export outputs/Q3Bar_`cohort'_temp.jpg, width(1200) quality(100) name(chapter`X') replace
	putdocx image outputs/Q3Bar_`cohort'_temp.jpg, linebreak
	putdocx pagebreak
}


** For named medicines
putdocx paragraph, style(Heading1)
putdocx text ("Results for named drug groups")

putdocx paragraph
putdocx text ("Figure 20. Opioids prescribed before and/or after a medication review ranked by most frequently 'started')"), linebreak bold
graph display opioids
graph export outputs/Q3Bar_`cohort'_temp.jpg, width(1200) quality(100) name(opioids) replace
putdocx image outputs/Q3Bar_`cohort'_temp.jpg, linebreak
putdocx pagebreak

putdocx paragraph
putdocx text ("Figure 21. Anticholinergic medicines prescribed before and/or after a medication review ranked by most frequently 'started')"), linebreak bold
graph display antichol
graph export outputs/Q3Bar_`cohort'_temp.jpg, width(1200) quality(100) name(antichol) replace
putdocx image outputs/Q3Bar_`cohort'_temp.jpg, linebreak
putdocx pagebreak

putdocx paragraph
putdocx text ("Figure 22. Gabapentinoids prescribed before and/or after a medication review ranked by most frequently 'started')"), linebreak bold
graph display gabapent
graph export outputs/Q3Bar_`cohort'_temp.jpg, width(1200) quality(100) name(gabapent) replace
putdocx image outputs/Q3Bar_`cohort'_temp.jpg, linebreak
putdocx pagebreak

putdocx paragraph
putdocx text ("Figure 23. Psychotropic medicines prescribed before and/or after a medication review ranked by most frequently 'started')"), linebreak bold
graph display psychotrop
graph export outputs/Q3Bar_`cohort'_temp.jpg, width(1200) quality(100) name(psychotrop) replace
putdocx image outputs/Q3Bar_`cohort'_temp.jpg, linebreak
putdocx pagebreak



** Remaining sensitivity analyses
putdocx paragraph, style(Heading1)
putdocx text ("Sensitivity analyses - varying time windows and outcome definition")

putdocx paragraph
putdocx text ("Figure 24. Medicines prescribed in the 6 months before and/or 6 months after a medication review (tablets only)"), linebreak bold
graph display sens_2_1
graph export outputs/Q3Bar_`cohort'_temp.jpg, width(1200) quality(100) name(sens_2_1) replace
putdocx image outputs/Q3Bar_`cohort'_temp.jpg, linebreak
putdocx pagebreak

putdocx paragraph
putdocx text ("Figure 25. Medicines prescribed in the 3 months before and/or 1-4 months after a medication review (tablets only)"), linebreak bold
graph display sens_3_1
graph export outputs/Q3Bar_`cohort'_temp.jpg, width(1200) quality(100) name(sens_3_1) replace
putdocx image outputs/Q3Bar_`cohort'_temp.jpg, linebreak
putdocx pagebreak

putdocx paragraph
putdocx text ("Figure 26. Medicines prescribed in the 1 month before and/or 1 month after a medication review (tablets only)"), linebreak bold
graph display sens_4_1
graph export outputs/Q3Bar_`cohort'_temp.jpg, width(1200) quality(100) name(sens_4_1) replace
putdocx image outputs/Q3Bar_`cohort'_temp.jpg, linebreak
putdocx pagebreak

putdocx paragraph
putdocx text ("Figure 27. Medicines prescribed in the 3 months before and/or 3 months after an IN-PERSON medication review (tablets only)"), linebreak bold
graph display sens_1_2
graph export outputs/Q3Bar_`cohort'_temp.jpg, width(1200) quality(100) name(sens_1_2) replace
putdocx image outputs/Q3Bar_`cohort'_temp.jpg, linebreak
putdocx pagebreak



** Main results sorted by total count 
putdocx paragraph
putdocx text ("Figure 28. Medicines prescribed before and/or after a medication review ranked by most frequently prescribed, drug-substance level (tablets only)"), linebreak bold
graph display main1tot
graph export outputs/Q3Bar_`cohort'_temp.jpg, width(1200) quality(100) name(main1tot) replace
putdocx image outputs/Q3Bar_`cohort'_temp.jpg, linebreak
putdocx pagebreak

putdocx paragraph
putdocx text ("Figure 29 Medicines prescribed before and/or after a medication review ranked by most frequently prescribed, BNF section level"), linebreak bold
graph display main2tot
graph export outputs/Q3Bar_`cohort'_temp.jpg, width(1200) quality(100) name(main2tot) replace
putdocx image outputs/Q3Bar_`cohort'_temp.jpg, linebreak
putdocx pagebreak

putdocx paragraph
putdocx text ("Figure 30. Medicines prescribed before and/or after a medication review ranked by most frequently prescribed, BNF chapter level"), linebreak bold
graph display main3tot
graph export outputs/Q3Bar_`cohort'_temp.jpg, width(1200) quality(100) name(main3tot) replace
putdocx image outputs/Q3Bar_`cohort'_temp.jpg, linebreak



*** SAVE FILE
local date: display %dCYND date("`c(current_date)'", "DMY")
putdocx save "outputs/Q3Figures_`cohort'_`date'.docx", replace





********************************************************************************
********************************************************************************





**# RESULTS TABLE
frame change default
capture frame drop outputs
frame put if analysis==1 & outcometype==1 & allmeds==0, into(outputs)
frame change outputs	

** Format string variables so suitable for output				
replace desc2=desc3 if desc3!=""
replace desc2=proper(desc2)

gen before=string(total_pre,"%9.1gc") + " (" + string(pc_pre,"%4.1f") + "%)"
gen after=string(total_post,"%9.1gc") + " (" + string(pc_post,"%4.1f") + "%)"

format pc_* %4.1f

gen dif2 = "+" + string(pc_dif,"%4.1f")
replace dif2 = substr(dif2,-4,.)

gen pc_befonly=100*(count_onlypre/n_elig_pop)
gen pc_aftonly=100*(count_onlypost/n_elig_pop)
gen pc_both=100*(count_both/n_elig_pop)
gen beforeonly =string(count_onlypre,"%9.1gc") + " (" + string(pc_befonly,"%4.1f") + "%)"
gen afteronly =string(count_onlypost,"%9.1gc") + " (" + string(pc_aftonly,"%4.1f") + "%)"
gen both =string(count_both,"%9.1gc") + " (" + string(pc_both,"%4.1f") + "%)"	

order desc2 form rank_onlypre beforeonly rank_onlypost afteronly both rank_pre before rank_post after dif2 
sort type rank_onlypost rank_onlypre

			
** Save as tables in word doc
capture putdocx clear
putdocx begin, landscape

putdocx paragraph, style(Title)
putdocx text ("Analysis question 3 - tables")

putdocx paragraph
putdocx text ("Table 4. Medicines ranked by most stopped - drug name"), bold
putdocx table tbl1=data(desc2-dif2) if ( rank_onlypre<=20 | rank_onlypost<=20) & type==1, varnames border(start,nil) border(insideV, nil) border(end,nil) 
putdocx table tbl1(.,.), font("", 9) 

order form, last
putdocx paragraph
putdocx text ("Table 2. Medicines ranked by most stopped - BNF section"), bold
putdocx table tbl1=data(desc2-dif2) if ( rank_onlypre<=20 | rank_onlypost<=20) & type==2, varnames border(start,nil) border(insideV, nil) border(end,nil)
putdocx table tbl1(.,.), font("", 9) 

putdocx paragraph
putdocx text ("Table 3. Medicines ranked by most stopped - BNF chapter"), bold
putdocx table tbl1=data(desc2-dif2) if ( rank_onlypre<=20 | rank_onlypost<=20) & type==3, varnames border(start,nil) border(insideV, nil) border(end,nil)
putdocx table tbl1(.,.), font("", 9) 


*** REPEAT for tablets only (redefine the rank variables)
keep if form=="tablets"
drop rank*
gsort analysis type outcometype -total_pre
by analysis type outcometype: gen rank_pre=_n

gsort analysis type outcometype -total_post
by analysis type outcometype: gen rank_post=_n

gsort analysis type outcometype -count_onlypost
by analysis type outcometype: gen rank_onlypost=_n

gsort analysis type outcometype -count_onlypre
by analysis type outcometype: gen rank_onlypre=_n

order desc2 rank_onlypre beforeonly rank_onlypost afteronly both rank_pre before rank_post after dif2 
sort type rank_onlypost rank_onlypre

putdocx paragraph
putdocx text ("Table 1. Medicines ranked by most stopped - drug name (tablets only)"), bold
putdocx table tbl1=data(desc2-dif2) if ( rank_onlypre<=20 | rank_onlypost<=20) & type==1, varnames border(start,nil) border(insideV, nil) border(end,nil) 
putdocx table tbl1(.,.), font("", 9) 



*** SAVE final file
local date: display %dCYND date("`c(current_date)'", "DMY")
putdocx save "outputs/Q3Results_`cohort'_`date'.docx", replace




*******************
capture log close Q3
frames reset
exit
