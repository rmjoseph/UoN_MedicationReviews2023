* Created 10 Mar 2023 by Rebecca Joseph, University of Nottingham
*************************************
* Name:	analysis_Q2_additional.do
* Creator:	RMJ
* Date:	20230310	
* Desc: Extra analyses for question 2 (sensitivity - results without dropping
*   people with extreme change in count; mean change for 10+meds at baseline;
*   tab of before/after; median counts before and after)
* Notes: 
* Version History:
*	Date	Reference	Update
* 20230310	analysis_Q2_additional	File started
* 20230313	analysis_Q2_additional	Create report
*************************************
args cohort
di "`cohort'"

** log
capture log close Q2A
local date: display %dCYND date("`c(current_date)'", "DMY")
log using "logs/analysisQ2_additional_`cohort'_`date'.txt", text replace name(Q2A)





** START
use data/prepared/`cohort'/`cohort'_prepared_dataset_Q2.dta, clear
keep if elig1==1 & analysis==1 & counttype==1
drop if sex==.
drop if medreview!=1
count

drop if before==0
count



**## WORD DOC ##**
capture putdocx clear
putdocx begin
putdocx paragraph, style(Title)
putdocx text ("Additional results for analysis question 2")





**# Before dropping people with extreme change in count
putdocx paragraph, style(Heading1)
putdocx text ("Mean difference before dropping >3sd")
		
putdocx paragraph
count
putdocx text ("Number included: ")
putdocx text (r(N)), nformat(%7.0fc) linebreak		
		
sum dif,d

**** Mean difference (overall, then 10+ meds only)			
collect clear
collect create models

collect _r_b _r_lb _r_ub _r_p, name(models) tag(model["overall"]): regress dif, vce(cluster pracid) 
collect _r_b _r_lb _r_ub _r_p, name(models) tag(model["10+ meds"]): regress dif if before>=10, vce(cluster pracid) 

collect style showbase off
collect style row stack, spacer
collect style cell border_block, border(right, pattern(nil))
collect style cell, font(,size(9))
collect style cell result [_r_b], nformat(%5.2f)
collect style cell result [_r_p], nformat(%5.3f)

collect composite define myci= _r_lb _r_ub, delimiter(", ")
collect style cell result[myci], nformat(%9.2f) sformat("(%s)")
collect composite define coeff= _r_b myci, trim override
collect composite define coeff2= coeff _r_p, delimiter(", p=")	

collect style header result, level(hide)
collect style column, extraspace(1)

collect preview

collect layout (colname#result[coeff2]) (model), name(models)
				
putdocx paragraph
putdocx text ("Table. Mean change in count (95% CI)")
collect style putdocx, layout(autofitcontents)
putdocx collect


**** Models					
fvset base 2 region
fvset base 5 ethnicity
fvset base 2 staffrole
fvset base 1 cot
fvset base 5 agecat
fvset base 3 blpoly			


collect clear
collect create models

collect _r_b _r_lb _r_ub _r_p, name(models) tag(model[(1)]): ///
	regress dif i.agecat i.sex, vce(cluster pracid) 

collect _r_b _r_lb _r_ub _r_p, name(models) tag(model[(2)]): ///
	regress dif i.agecat i.sex i.blpoly, vce(cluster pracid) 
	
collect _r_b _r_lb _r_ub _r_p, name(models) tag(model[(3)]): ///
	regress dif i.agecat i.sex i.blpoly i.region_country ///
		i.cot i.staffrole, vce(cluster pracid) 

collect _r_b _r_lb _r_ub _r_p, name(models) tag(model[(4)]): ///
	regress dif i.agecat i.sex i.blpoly i.region_country ///
		i.cot i.staffrole i.townsend, vce(cluster pracid) 

collect style showbase off
collect style row stack, spacer
collect style cell border_block, border(right, pattern(nil))
collect style cell, font(,size(9))
collect style cell result [_r_b], nformat(%5.2f)
collect style cell result [_r_p], nformat(%5.3f)

collect composite define myci= _r_lb _r_ub, delimiter(", ")
collect style cell result[myci], nformat(%9.2f) sformat("(%s)")
collect composite define coeff= _r_b myci, trim override
collect composite define coeff2= coeff _r_p, delimiter(", p=")	

collect style header result, level(hide)
collect style column, extraspace(1)

collect preview

collect layout (colname#result[coeff2]) (model), name(models)

putdocx sectionbreak, landscape
putdocx paragraph
putdocx text ("Table. Linear regression models for change in count before dropping if >3sd")
collect style putdocx, layout(autofitcontents) note("Note: coefficient (95% confidence interval), p-value") 
putdocx collect		




**# Mean change in people with 10+ meds AFTER dropping extremes
sum dif,d
keep if (dif >= r(mean) - 3*r(sd)) & (dif <= r(mean) + 3*r(sd)) 	
count

putdocx paragraph, style(Heading1)
putdocx text ("Mean difference AFTER dropping >3sd")	
		
count
putdocx text ("Number included: ")
putdocx text (r(N)), nformat(%7.0fc) linebreak		



collect clear
collect create models

collect _r_b _r_lb _r_ub _r_p, name(models) tag(model["overall"]): regress dif, vce(cluster pracid) 
collect _r_b _r_lb _r_ub _r_p, name(models) tag(model["10+ meds"]): regress dif if before>=10, vce(cluster pracid) 

collect style showbase off
collect style row stack, spacer
collect style cell border_block, border(right, pattern(nil))
collect style cell, font(,size(9))
collect style cell result [_r_b], nformat(%5.2f)
collect style cell result [_r_p], nformat(%5.3f)

collect composite define myci= _r_lb _r_ub, delimiter(", ")
collect style cell result[myci], nformat(%9.2f) sformat("(%s)")
collect composite define coeff= _r_b myci, trim override
collect composite define coeff2= coeff _r_p, delimiter(", p=")	

collect style header result, level(hide)
collect style column, extraspace(1)

collect preview

collect layout (colname#result[coeff2]) (model), name(models)
				
putdocx paragraph
putdocx text ("Table. Mean change in count (95% CI) accounting for practice-level clusters")
collect style putdocx, layout(autofitcontents)
putdocx collect




**# Tabulation of pres count before and after
egen aftcat=cut(after), at(0 1 2 5 10 15 20 100) icodes
label values aftcat polypharm
bys aftcat: sum(after)

tab  aftcat blpoly,m co

table (var) (blpoly),	///
	statistic(fvfrequency aftcat) ///
	statistic(fvpercent aftcat) ///
	name(Table1) replace
	
collect recode result 	fvfrequency = count	///
						fvpercent   = percent

collect style cell result[count], nformat(%9.0fc)
collect style cell result[percent], nformat(%4.1fc) sformat("(%s%%)")
collect composite define countperc = count percent, delimiter(" ") 

collect layout (var#result[countperc]) (blpoly)

collect style row split
collect style cell border_block, border(right, pattern(nil))

collect preview
putdocx paragraph
putdocx text ("Table. original count vs new count, column %")
collect style putdocx, layout(autofitcontents)
putdocx collect


qui table (var) (),	///
	statistic(fvfrequency blpoly aftcat) ///
	statistic(fvpercent blpoly aftcat) ///
	name(Table1) replace

qui table agecat, statistic(mean dif) statistic(sd dif) nototal name(Table2) replace
foreach VAR of varlist blpoly aftcat {
	qui table `VAR', statistic(mean dif) statistic(sd dif) nototal name(Table2) append
}

collect combine new = Table1 Table2, replace	
collect recode result 	fvfrequency = Count	///
						fvpercent   = percent			
collect style cell result[Count], nformat(%9.0fc) // COUNT
collect style cell result[percent], nformat(%4.1fc) sformat("(%s%%)") // PERCENTAGE
collect composite define newcount = Count percent, delimiter(" ") 

collect style cell result[mean], nformat(%4.2fc) 
collect style cell result[sd], nformat(%4.2fc) sformat("(%s)")
collect composite define newmean = mean sd, delimiter(" ") 

collect layout (blpoly aftcat) (result[newcount newmean])
collect style cell, font(,size(9))
collect style row stack, nobinder spacer
collect style cell border_block, border(right, pattern(nil))

collect preview
putdocx paragraph
putdocx text ("Table. overall original count and new count")
collect style putdocx, layout(autofitcontents)
putdocx collect



**# Tabulation of median pres count before and after
table (var) (),	///
	statistic(median before after) ///
	statistic(p25 before after)	///
	statistic(p75 before after)

collect preview
putdocx paragraph
putdocx text ("Table. median (IQR) count before after")
collect style putdocx, layout(autofitcontents)
putdocx collect



local date: display %dCYND date("`c(current_date)'", "DMY")
putdocx save "outputs/Q2ResultsAdditional_`cohort'_`date'.docx", replace

*******************
capture log close Q2A
frames reset
exit







