* Created 07 Sept 2022 by Rebecca Joseph, University of Nottingham
*************************************
* Name:	prep_whichdrugs_v2.do
* Creator:	RMJ
* Date:	20220907	
* Desc: compares which drugs are prescribed before and after a review
* Notes: 
* Version History:
*	Date	Reference	Update
* 20220907	prep_whichdrugs	Combine 3 count types in one file, inc _N
* 20221003	prep_whichdrugs_v2	Add 4th loop for the new 1m analysis
* 20221003	prep_whichdrugs_v2	Increment labels by 4 not 3
* 20230124	prep_whichdrugs_v2	Save new version
* 20230124	prep_whichdrugs_v3	Flag specific medicines
* 20230125	prep_whichdrugs_v3	New var for outcome type (sensit main)
* 20230125	prep_whichdrugs_v3	Counts by desc not code (when drug name) (>1 formulation)
* 20230126	prep_whichdrugs_v3	Update order & drop code to avoid bug with duplicate descs
* 20230127	prep_whichdrugs_v3	Move spec of d_* vars to end of loop
* 20230127	prep_whichdrugs_v3	Add final data cleaning to this script
* 20230127	prep_whichdrugs_v3	Extra loop to create results for all meds here
* 20230302	prep_whichdrugs_v3	Tidy script
*************************************


** NEED TO RUN THIS FROM THE MASTERFILE SO ARGUMENT 'COHORT' IS DEFINED
args cohort
di "`cohort'"

frames reset
set more off

**# Set up required frames
frame create cohort
frame create windows
frame create bnfinfo
frame create pre
frame create post
frame create combine

**# Prepare drugs lookup file
frame create drugs
frame drugs {
	use prodcode drugnamecode drugname using data/prepared/`cohort'/drugnames_clean.dta, clear
	merge 1:1 prodcode using data/prepared/`cohort'/bnfchapters_clean.dta, keepusing(prodcode chapter chaptdesc bnfcode_num bnfdesc) 
	drop _merge
	
	replace drugnamecode = 99999 if drugnamecode==.
	replace drugname = "Unknown" if drugnamecode==99999
	
	replace chapter=99 if chapter>=14
	replace chaptdesc="Chapter unknown" if chapter==99
	
	replace bnfcode_num=999999 if bnfcode_num==.
	replace bnfdesc="Unknown" if bnfcode_num==999999	
	
	*** Rename vars for later
	rename drugnamecode code1
	rename drugname desc1
	rename bnfcode_num code2
	rename bnfdesc desc2
	rename chapter code3
	rename chaptdesc desc3

	**** STRING bnf code with leading 0
	tostring code2, gen(bnf)
	replace bnf = "0" + bnf
	replace bnf = substr(bnf,-6,.)	

} 


**# LOOP: first is main analysis and second is conservative defn of med reviews
forval sensit=1/3 {
	
	*** use local to specify sensitivity analysis suffix
	if `sensit'==2 local sens "_s"
	else local sens


	**# Make eligibility lookup
	frame cohort {
		clear
		use patid sex medreview`sens' using data/prepared/`cohort'/`cohort'_prepared_dataset_Q1.dta
		keep if medreview`sens'==1
		drop if sex==.
		drop sex
	}

	frame windows {
		clear
		use data/prepared/`cohort'/timewindows_Q2`sens'.dta, clear
		frlink 1:1 patid, frame(cohort)
		keep if cohort<.
		drop cohort
		
		egen count_elig3 = sum(elig3)
		egen count_elig4 = sum(elig4)
		egen count_elig6 = sum(elig6)
		egen count_elig1 = sum(elig1)
	}


				
	**# NEW LOOP - 4 sets of time windows
	forval loop=1/4 {
		
		**# NEW LOOP, 3 vars to summarise counts by
		forvalues V=1/3 {
				
			*** Open appropriate datasets
			if `loop'==1 {
				frame pre: use data/prepared/`cohort'/drugsinwindow_3mpre`sens'.dta, clear
				frame post: use data/prepared/`cohort'/drugsinwindow_3mpost`sens'.dta, clear
			}
			if `loop'==2 {
				frame pre: use data/prepared/`cohort'/drugsinwindow_6mpre`sens'.dta, clear
				frame post: use data/prepared/`cohort'/drugsinwindow_6mpost`sens'.dta, clear
			}
			if `loop'==3 {
				frame pre: use data/prepared/`cohort'/drugsinwindow_3mpre`sens'.dta, clear
				frame post: use data/prepared/`cohort'/drugsinwindow_4mpost`sens'.dta, clear
			}
			if `loop'==4 {
				frame pre: use data/prepared/`cohort'/drugsinwindow_1mpre`sens'.dta, clear
				frame post: use data/prepared/`cohort'/drugsinwindow_1mpost`sens'.dta, clear
			}

			
			**# NEW LOOP - simplify the pre and post datasets, and count type
			foreach X of newlist pre post {

				frame change `X'
				drop if formulation==10	// non-drug formulation
				if `sensit'<3    drop if issueseq==0 // not a repeat prescn
				keep patid prodcode formulation
				duplicates drop

				*** Link to druginfo frame to get name code
				frlink m:1 prodcode, frame(drugs)
				frget code`V' desc`V' bnf, from(drugs)
				drop drugs
				drop prodcode
				
				*** Combine formulation with name
				decode form, gen(form_s)
				replace form_s="unknown" if form_s==""
				
				if `V'==1  replace desc = desc + " (" + form_s + ")"
				drop formulation form_s
				
				*** Where same name and same form but >1 BNF, replace bnf with most common
				*** (before meds flags, which use bnf)
				bys desc bnf: gen count=_N
				bys desc (count): replace bnf=bnf[_N] 
				drop count
				
				duplicates drop
				
				*** Get count variable
				frlink m:1 patid, frame(windows)
				keep if windows<.
				if `loop'==1 frget elig3 count_elig3, from(windows)
				if `loop'==2 frget elig6 count_elig6, from(windows)
				if `loop'==3 frget elig4 count_elig4, from(windows)
				if `loop'==4 frget elig1 count_elig1, from(windows)
				
				keep if elig==1
				drop windows elig

				*** Keep one record of each prescribed drug per patient (should be no dups now)
				if `V'!=1  bys patid code`V': keep if _n==1
				if `V'==1  bys patid desc: keep if _n==1	// may be dups in code but shouldn't be in desc (dif forms)
				gen prescd = 1

			} // close "X"


			
			
			
			*** Append the two time windows and reshape wide to compare drugs prescd
			*** pre- and post-review
			frame post: gen period=1

			frame change pre
			gen period=0
			frameappend post

			 if `V'==1  replace code=.
			
			reshape wide prescd, i(patid code desc count_elig bnf) j(period)
			recode prescd* (.=0)

					
			*** Create indicators for whether drug was in both windows or only one
			gen both=(prescd0==prescd1==1)
			gen stopped=(prescd0==1 & prescd1==0)
			gen started=(prescd0==0 & prescd1==1)

			*** Calculate the number of people prescribed each drug in the different windows
			foreach X of varlist prescd0-started {
				bys desc: egen c_`X'=sum(`X') // dups of count, not of desc
			}

			*** Keep one record per drug
			drop patid
			sort code desc

			drop prescd0-started
			duplicates drop

			
			*** Flags for specific medicines (same as in prep_baselinedrugs.do)
			gen d_opioids=(bnf=="040702")|regexm(desc,"dihydrocodeine|codeine|dextropropoxyphene")==1

			gen d_gabapentinoid=regexm(desc,"pregabalin|gabapentin")==1

			#delimit ;
			local achlist 
			disopyramide|amitriptyline|
			amoxapine|clomipramine|desipramine|doxepin|imipramine|nortriptyline|paroxetine|protriptyline|
			trimipramine|prochlorperazine|promethazine|pyrilamine|triprolidine|brompheniramine|
			carbinoxamine|chlorpheniramine|clemastine|cyproheptadine|dexbrompheniramine|dexchlorpheniramine|
			dimenhydrinate|diphenhydramine|doxylamine|hydroxyzine|meclizine|clidinium-chlordiazepoxide|
			dicyclomine|homatropine|hyoscyamine|methscopolamine|propantheline|darifenacin|fesoterodine|flavoxate|
			oxybutynin|solifenacin|tolterodine|trospium|benztropine|trihexyphenidyl|chlorpromazine|clozapine|
			loxapine|olanzapine|perphenazine|thioridazine|trifluoperazine|atropine|belladonna|scopolamine|
			cyclobenzaprine|orphenadrine|dosulepin|lofepramine|cyclizine|dimenhydrinate|promazine|azatadine|
			chlorphenamine|trimeprazine|alimemazine|propiverine|benzatropine|orphenadrine|methotrimeprazine|
			levomepromazine|pericyazine|
			perphenazine|pimozide|quetiapine|alverine|dicyclomine|dicycloverine|propantheline|hyoscine|
			carbamazepine|oxcarbazepine|methocarbamol|tizanidine|glycopyrrolate|glycopyrronium|ipratropium;
			#delimit cr
			gen d_ach=(regexm(desc,"`achlist'")==1)
			replace d_ach=0 if regexm(desc,"(drops)")==1
			replace d_ach=0 if regexm(desc,"diphenhydramine")==1 & regexm(desc,"(tablets)")!=1
			
			gen d_psychotrop=(regexm(bnf,"^0401|^0402|^0403")==1)

			if `V'!=1 recode d_* (0=.) (1=.)
			

			
			
			*** Calculate the % of records prescribed in window 0 that were not in 1
			*** and same for drugs in window 1 that were not in 0
			gen pc_pre_oftot = 100*(c_prescd0/count_elig)
			gen pc_post_oftot = 100*(c_prescd1/count_elig)

			gen pc_onlypre_ofpre = 100*(c_stopped/c_prescd0)
			gen pc_onlypost_ofpost = 100*(c_started/c_prescd1)

			*** Tidy
			rename c_prescd0 total_pre
			rename c_prescd1 total_post
			rename c_both count_both
			rename c_stopped count_onlypre
			rename c_started count_onlypost
			rename count_elig n_elig_pop
			order code desc 

			rename code code
			rename desc desc
			
			replace bnf=substr(bnf,1,4)
			
			*** Drop low counts
			foreach X of varlist count* {
				drop if `X'<5
			}
			
			drop if total_pre<10
			drop if total_post<10

			*** Ranks
			gsort -total_pre
			gen rank_pre=_n

			gsort -total_post
			gen rank_post=_n

			gen pc_dif=pc_post-pc_pre
			order pc_dif, after(pc_post_oftot)

			gsort -count_onlypost
			gen rank_onlypost=_n

			gsort -count_onlypre
			gen rank_onlypre=_n			
						
			sort rank_pre			
			
			*** Prepare to combine
			gen analysis=`loop'
			gen type=`V'
			gen outcometype=`sensit'
			gen allmeds=(`sensit'==3)
			frame combine: frameappend pre

		} // close "V"
	
		if `sensit'==3 		continue, break // (exits 'loop' without running the rest)

	} // close "loop"

} // close "sensit"



*** Cleaning & finalising
frame change combine
format desc %50s

**** Labels
label define analysis 1 "3 months" 2 "6 months" 3 "4 months" 4 "1 month"
label values analysis analysis

label define type 1 "Drug name" 2 "BNF paragraph" 3 "BNF chapter"
label values type type

label define outcome 1 "Main" 2 "Sensitivity"
label values outcometype outcome

label define allmeds 0 "Repeat prescs only" 1 "Repeat and non-repeat prescs"
label values allmeds allmeds

**** Create code2 (processed string version of code for bnf section and chapter)
gen code2=string(code)
replace code2="" if type==1
replace code2= "0" + code2 if type!=1
replace code2=substr(code2,-6,6) if type==2
replace code2=substr(code2,1,2) + "." + substr(code2,3,2) + "." + substr(code2,5,2) if type==2
replace code2="Chapter " + substr(code2,-2,2) if type==3

**** Create desc2 (include BNF section/chapter at end of desc)
gen desc2=desc
replace desc2 = code2 + " (" + desc2 + ")" if type!=1
format desc2 %50s

**** Renaming specific meds
replace desc2 = "macrogol 3350 (other)" if desc2=="bicarbonate + chloride + macrogol 3350 + potassium + sodium (other)"

**** Formulation, and description without formulation (desc3)
split desc2 if type==1, gen(form) parse("(") limit(2)
format form* %50s
replace form2=subinstr(form2,")","",.)

rename form2 form
rename form1 desc3

replace form="unknown" if form=="" & type==1

replace desc3="hyoscine (base)" if regexm(form,"base")==1
replace form="patches" if regexm(form,"base")==1



** SAVE AND END
compress
format desc* %50s
order code desc code2 desc2 desc3 form outcometype analysis type allmeds 
save data/prepared/`cohort'/`cohort'_prepared_dataset_Q3.dta, replace
export delimited using outputs/`cohort'_MedsBeforeAfterReview.csv, replace

*****	
frames reset
exit


