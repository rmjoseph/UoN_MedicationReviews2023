* Created 11 Jan 2023 by Rebecca Joseph, University of Nottingham
*************************************
* Name:	analysis_Q2_v2.do
* Creator:	RMJ
* Date:	20230111	
* Desc: code for analysis question 2 (change in numbers of medicines)
* Notes: 
* Version History:
*	Date	Reference	Update
* 20221012	analysis_Q2_draft	File started
* 20221014	analysis_Q2 Fix bug - change how elig vars are renamed
* 20221018	analysis_Q2	Finish adding putdocx commands
* 20221018	analysis_Q2	Update counts section to account for multiple records
* 20221024	analysis_Q2	Remove ethnicity from last model
* 20230111	analysis_Q2	Save new version
* 20230111	analysis_Q2_v2 Adapt code to updated version of dataset
* 20230119	analysis_Q2_v2 Add line restricting variables in loops so sensitivity runs properly
* 20230119	analysis_Q2_v2 Update tables to include mean (SD) dif by characteristic
* 20230123	analysis_Q2_v2 Improve resolution of bar charts; also export as pdf
* 20230123	analysis_Q2_v2 Add country-level region into bl charas table and graph
* 20230123	analysis_Q2_v2 Replace region with region_country in regression
* 20230123	analysis_Q2_v2 Add table calculating overall mean (SD)
* 20230302	analysis_Q2_v2 Tidy file
*************************************

set scheme cleanplots
set more off
frames reset

args cohort
di "`cohort'"

** log
capture log close Q2
local date: display %dCYND date("`c(current_date)'", "DMY")
log using "logs/analysisQ2_`cohort'_`date'.txt", text replace name(Q2)


*** OPEN DATASET
use data/prepared/`cohort'/`cohort'_prepared_dataset_Q2.dta, clear
frame put patid sex medreview* elig*, into(counts)
frame counts: duplicates drop

drop if sex==.
label var region_country "Practice region"

**## WORD DOC ##**
capture putdocx clear
putdocx begin
putdocx paragraph, style(Title)
putdocx text ("Results for analysis question 2")

putdocx textblock begin, paramode
KEY 

Analysis: 1 = main, 2 = 6 months, 3 = 4months, 4 = 1 month

Outcome: 1 = only repeat meds, 2 = all meds, 3 = only repeat medicines AND only tablets
putdocx textblock end
******************


*** Loop over medication review type (main/sensitivity)
forval M=1/2 {	// 1
	display "Sensitivity loop `M'"
	
	local sens 
	if `M'==2 local sens "_s"

	putdocx paragraph, style(Heading1)
	putdocx text ("Medication review definition #`M' (1=main, 2=sensitivity)")
	
	*** Loop over analysis 
	forval A=1/4 { // 2
		display "Analysis loop `A'"

		putdocx paragraph, style(Heading1)
		putdocx text ("Results for analysis #`A'")	
		
		**# Report numbers
		frame counts {
			putdocx paragraph
			count 
			putdocx text ("Number at start: ")
			putdocx text (r(N)), nformat(%7.0fc) linebreak
			
			count if sex==.
			putdocx text ("Number missing sex, dropped: ")
			putdocx text (r(N)), nformat(%7.0fc) linebreak			
			
			count if sex!=.
			count if sex!=. & medreview`sens'!=1
			putdocx text ("Number with no medication review, dropped: ")
			putdocx text (r(N)), nformat(%7.0fc) linebreak			
			
			count if sex!=. & medreview`sens'==1
			count if sex!=. & medreview`sens'==1 & elig`A'!=1
			putdocx text ("Number with insufficient follow-up, dropped: ")
			putdocx text (r(N)), nformat(%7.0fc) linebreak		
			
			count if sex!=. & medreview`sens'==1 & elig`A'==1
			putdocx text ("Number included: ")
			putdocx text (r(N)), nformat(%7.0fc) linebreak			
		}
		
		
		*** Loop over count type
		forval C=1/3 { //3
			capture frame drop temp
			frame put if elig`A'==1 & analysis==`A' & counttype==`C', into(temp)
			frame temp {
				drop if sex==.
				drop if medreview`sens'!=1
				
				keep patid pracid elig`A' medreview`sens' dif`sens' before`sens' after`sens' age* sex ///
					region* townsend ethnicity blpoly`sens' cot`sens' staffrole`sens' 

				putdocx paragraph, style(Heading1)
				putdocx text ("Results for outcome #`C'")				
				
				putdocx paragraph
				count if sex!=. & medreview`sens'==1 & elig`A'==1
				putdocx text ("Starting count: ")
				putdocx text (r(N)), nformat(%7.0fc) linebreak		

				**# Output descriptive tables and graphs
				*** Table: count and mean before dropping obs
				table () (result), statistic(frequency) statistic(mean dif) statistic(sd dif)
				collect style cell result[mean], nformat(%4.2fc) 
				collect style cell result[sd], nformat(%4.2fc) sformat("(%s)")
				collect composite define newmean = mean sd, delimiter(" ") 
				collect layout () (result[frequency newmean])				

				putdocx paragraph
				collect style putdocx, layout(autofitcontents) 
				putdocx text ("Table. Count and mean (SD) difference overall, before dropping extreme values")
				putdocx collect
				
				*** Table: counts & mean dif by characteristics before dropping any obs
				qui table (var) (),	///
					statistic(fvfrequency agecat sex blpoly ethnicity townsend region region_country staffrole cot) ///
					statistic(fvpercent agecat sex blpoly ethnicity townsend region region_country staffrole cot) ///
					name(Table1) replace

				qui table agecat, statistic(mean dif) statistic(sd dif) nototal name(Table2) replace
				foreach VAR of varlist sex blpoly ethnicity townsend region region_country staffrole cot {
					qui table `VAR', statistic(mean dif) statistic(sd dif) nototal name(Table2) append
				}

				collect combine new = Table1 Table2, replace	
				collect dims
				collect recode result 	fvfrequency = Count	///
										fvpercent   = percent			
				collect style cell result[Count], nformat(%9.0fc) // COUNT
				collect style cell result[percent], nformat(%4.1fc) sformat("(%s%%)") // PERCENTAGE
				collect composite define newcount = Count percent, delimiter(" ") 

				collect style cell result[mean], nformat(%4.2fc) 
				collect style cell result[sd], nformat(%4.2fc) sformat("(%s)")
				collect composite define newmean = mean sd, delimiter(" ") 

				collect layout (agecat sex blpoly ethnicity townsend region region_country staffrole cot) (result[newcount newmean])
				collect style cell, font(,size(9))
				collect style row stack, nobinder spacer
				collect style cell border_block, border(right, pattern(nil))

				collect preview
				
				putdocx paragraph
				collect style putdocx, layout(autofitcontents) 
				putdocx text ("Table. Count (%) and mean (SD) difference by characteristics before dropping extreme values")
				putdocx collect

				
				*** Histogram of difference before dropping obs
				histogram dif`sens', width(.99) xtitle("Difference") ///
					title("A. Before dropping extreme values") name(hist1,replace) ///
					nodraw

					
				**# Drop people with extreme values of dif and with 0 meds before review		
				** Drop people with 0 medicines before review
				count if before`sens'==0
				putdocx paragraph
				putdocx text ("Drop people prescribed zero medicines before the review: N=")
				putdocx text (r(N)), nformat(%7.0fc)		
								
				drop if before`sens'==0
				count

				** Drop people with extreme values of dif
				qui sum dif`sens', d
				local low = r(mean) - 3*r(sd)
				local high = r(mean) + 3*r(sd)
				
				count if (dif`sens' < r(mean) - 3*r(sd)) | (dif`sens' > r(mean) + 3*r(sd)) 
				putdocx paragraph
				putdocx text ("Drop people with a change of more than +-3SD from mean (range ")
				putdocx text ("`low'"), nformat(%5.2f)
				putdocx text (" to ")
				putdocx text ("`high'"), nformat(%5.2f)
				putdocx text ("): N=")
				putdocx text (r(N)), nformat(%7.0fc)
				
				sum dif`sens',d
				keep if (dif`sens' >= r(mean) - 3*r(sd)) & (dif`sens' <= r(mean) + 3*r(sd)) 		
								
				count
				putdocx paragraph
				putdocx text ("People remaining: N=")
				putdocx text (r(N)), nformat(%7.0fc)		
						
				*** Table: count and mean AFTER dropping obs
				table () (result), statistic(frequency) statistic(mean dif) statistic(sd dif)
				collect style cell result[mean], nformat(%4.2fc) 
				collect style cell result[sd], nformat(%4.2fc) sformat("(%s)")
				collect composite define newmean = mean sd, delimiter(" ") 
				collect layout () (result[frequency newmean])				

				putdocx paragraph
				collect style putdocx, layout(autofitcontents) 
				putdocx text ("Table. Count and mean (SD) difference overall, after dropping extreme values")
				putdocx collect
				
				*** Table: counts & mean dif by characteristics after dropping any obs
				qui table (var) (),	///
					statistic(fvfrequency agecat sex blpoly ethnicity townsend region region_country staffrole cot) ///
					statistic(fvpercent agecat sex blpoly ethnicity townsend region region_country staffrole cot) ///
					name(Table1) replace

				qui table agecat, statistic(mean dif) statistic(sd dif) nototal name(Table2) replace
				foreach VAR of varlist sex blpoly ethnicity townsend region region_country staffrole cot {
					qui table `VAR', statistic(mean dif) statistic(sd dif) nototal name(Table2) append
				}

				collect combine new = Table1 Table2, replace	
				collect dims
				collect recode result 	fvfrequency = Count	///
										fvpercent   = percent			
				collect style cell result[Count], nformat(%9.0fc) // COUNT
				collect style cell result[percent], nformat(%4.1fc) sformat("(%s%%)") // PERCENTAGE
				collect composite define newcount = Count percent, delimiter(" ") 

				collect style cell result[mean], nformat(%4.2fc) 
				collect style cell result[sd], nformat(%4.2fc) sformat("(%s)")
				collect composite define newmean = mean sd, delimiter(" ") 

				collect layout (agecat sex blpoly ethnicity townsend region region_country staffrole cot) (result[newcount newmean])
				collect style cell, font(,size(9))
				collect style row stack, nobinder spacer
				collect style cell border_block, border(right, pattern(nil))

				collect preview
				
				putdocx paragraph
				collect style putdocx, layout(autofitcontents) 
				putdocx text ("Table. Count (%) and mean (SD) difference by characteristics after dropping extreme values")
				putdocx collect
				

				
	
				
				
				*** Histogram of difference after dropping obs
				histogram dif`sens', width(.99) xtitle("Difference") ///
					title("B. After dropping extreme values") ///
					name(hist2,replace) nodraw
				graph combine hist1 hist2, xcommon
				graph export outputs/`cohort'_difhist_`A'`C'`sens'.tif, replace
				
				putdocx pagebreak
				putdocx paragraph
				putdocx text ("Figure. Histogram, difference in count")
				putdocx paragraph
				putdocx image outputs/`cohort'_difhist_`A'`C'`sens'.tif
				
		
				*** Bar charts summarising dif by characteristics
				foreach X of varlist agecat sex ethnicity townsend region_country staffrole cot blpoly`sens' {
					graph hbar (mean) dif`sens', over(`X') name(hb_`X', replace) ///
						ytitle("Mean difference in count") ///
						title(`: variable label `X'') ylabel(-.5(.1).5) yline(0, lpattern(1)) nodraw
				}

				graph combine hb_agecat hb_blpoly hb_sex hb_ethnicity hb_townsend ///
					hb_region_country hb_staffrole hb_cot, iscale(0.4) ycommon cols(2) ysize(6) xcommon

				graph export outputs/`cohort'_difbar_`A'`C'`sens'.tif, replace width(1200)
				graph export outputs/`cohort'_difbar_`A'`C'`sens'.pdf, replace
				
				putdocx pagebreak
				putdocx paragraph
				putdocx text ("Figure. Bar charts, difference in count")
				putdocx paragraph
				putdocx image outputs/`cohort'_difbar_`A'`C'`sens'.tif
				
				
								
				**# Mean of dif		
				collect clear
				collect create models
				
				collect _r_b _r_lb _r_ub _r_p: regress dif`sens', vce(cluster pracid) 

				collect style cell border_block, border(right, pattern(nil))
				collect style cell, font(,size(9))
				collect style cell result [_r_b], nformat(%5.2f)
				collect style cell result [_r_p], nformat(%5.3f)
				
				collect composite define myci= _r_lb _r_ub, delimiter(", ")
				collect style cell result[myci], nformat(%9.2f) sformat("(%s)")
				collect composite define coeff= _r_b myci, trim override
				collect composite define coeff2= coeff _r_p, delimiter(", p=")	
				
				collect layout (colname) (result[coeff2])
								
				putdocx paragraph
				putdocx text ("Table. Mean change in count (95% CI) accounting for practice-level clusters")
				collect style putdocx, layout(autofitcontents)
				putdocx collect
				

		
		
				**# Regression		
				fvset base 2 region
				fvset base 5 ethnicity
				fvset base 2 staffrole
				fvset base 1 cot
				fvset base 5 agecat
				if "`cohort'"=="ad" fvset base 4 agecat
				fvset base 3 blpoly			
				
				
				collect clear
				collect create models
				
				collect _r_b _r_lb _r_ub _r_p, name(models) tag(model[(1)]): ///
					regress dif`sens' i.agecat i.sex, vce(cluster pracid) 

				collect _r_b _r_lb _r_ub _r_p, name(models) tag(model[(2)]): ///
					regress dif`sens' i.agecat i.sex i.blpoly`sens', vce(cluster pracid) 
					
				collect _r_b _r_lb _r_ub _r_p, name(models) tag(model[(3)]): ///
					regress dif`sens' i.agecat i.sex i.blpoly`sens' i.region_country ///
						i.cot i.staffrole, vce(cluster pracid) 

				collect _r_b _r_lb _r_ub _r_p, name(models) tag(model[(4)]): ///
					regress dif`sens' i.agecat i.sex i.blpoly`sens' i.region_country ///
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
				putdocx text ("Table. Linear regression models for change in count, accounting for practice-level clusters")
				collect style putdocx, layout(autofitcontents) note("Note: coefficient (95% confidence interval), p-value") 
				putdocx collect
				
				putdocx sectionbreak
				
				
				
				
			} // close frame temp
		
		
		} //3
		
		
		
	} //2
	
	
} //1





local date: display %dCYND date("`c(current_date)'", "DMY")
putdocx save "outputs/Q2Results_`cohort'_`date'.docx", replace

*******************
capture log close Q2
frames reset
exit


