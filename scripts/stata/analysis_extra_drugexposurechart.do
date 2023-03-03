* Created 2022-10-26 by RMJ, University of Nottingham
*************************************
* Name:	analysis_extra_drugexposurechart.do
* Creator:	RMJ
* Date:	20221026	
* Desc: Outputs a graph of drug exposure for one example patient
* Notes: cleanplots
* Version History:
*	Date	Reference	Update
* 20221024	analysis_Q3_draft	First clean draft
*************************************

frames reset
set scheme cleanplots

** Just use over65s cohort - example
use patid prodcode start stop formulation using "data/prepared/over65s/drugsinwindow_3mpre.dta", clear
gen pre=1
append using "data/prepared/over65s/drugsinwindow_3mpost.dta", keep(patid prodcode start stop formulation)
replace pre=0 if pre==.

merge m:1 patid using "data/prepared/over65s/timewindows_Q2.dta", keepusing(review r_minus3)
keep if _merge==3
drop _merge

** Create new id so can mask the patid when sharing
bys patid (start stop prodcode formulation): gen id=1 if _n==1
replace id = sum(id)

** Mask real dates
gen start1 = start-r_minus3
gen stop1 = stop-r_minus3
gen review1 = review-r_minus3

replace stop1 = 182 if stop1>182

** Mask drug names (encode & relabel below)
tostring prodcode, gen(drugname)

** Draw graph for one example person
capture frame drop GRAPH
*frame put if id==270998, into(GRAPH) // original
frame put if id==283269, into(GRAPH)
frame GRAPH {
	
	label define druglab 0 " " 1 "Drug A" 2 "Drug B" 3 "Drug C" 4 "Drug D" 5 "Drug E" 6 "Drug F" ///
	7 "Drug G" 8 "Drug H" 9 "Drug I" 10 "Drug J" 11 "Drug K" 12 "Drug L", replace

	
	encode drugname, gen(drugnum)
	label values drugnum druglab

	qui sum drugnum
	local pos = `r(max)' + .1
	tw  (rbar start1 stop1 drugnum if pre==1, hor barw(.1)) ///
		(rbar start1 stop1 drugnum if pre==0, hor barw(.1)), ///
		ylab(1(1)`r(max)',val angle(0)) yti("") ///
		xlab(0(7)182, grid) xtitle("Follow-up (days)") ///
		xline(92) ///
		legend(title("Prescription issued:") label(1 "Before review") label(2 "After review")) ///
		scale(0.6) name(all,replace) 

	drop drugnum
}

graph export outputs/over65s_exampleprescribing.tif, name(all) replace


frames reset
exit
