* Created 12 Oct 2022 by Rebecca Joseph, University of Nottingham
*************************************
* Name:	prep_polypharmacycount_v2.do
* Creator:	RMJ
* Date:	20221012	
* Desc: Splits presc drugnamecodeords into periods of overlapping exposure and counts the max number of 
*		overlapping drugs
* Notes: 
* Version History:
*	Date	Reference	Update
* 20220720	new file	DRAFT FILE CREATED
* 20220825	prep_polypharmacycount	Add formulation into the grouping 
* 20221003	prep_polypharmacycount	Additional steps for 1mpre and 1mpost datasets
* 20221003	prep_polypharmacycount	Add use USING to ~line 61 for efficiency
* 20221012	prep_polypharmacycount	(NEW VERSION) Just prep sliced dataset
* 20221012	prep_polypharmacycount_v2	Include issueseq to flag repeats	
* 20221012	prep_polypharmacycount_v2	Make 3 versions of count variable	
* 20221012	prep_polypharmacycount_v2	Write loop for combining all counts
* 20230302	prep_polypharmacycount_v2	Tidy script
*************************************

** NEED TO RUN THIS FROM THE MASTERFILE SO ARGUMENT 'COHORT' IS DEFINED
args cohort
di "`cohort'"

** log
capture log close counts
local date: display %dCYND date("`c(current_date)'", "DMY")
log using "logs/`cohort'_countsinwindow_`date'.txt", text append name(counts)

** clear memory
set more off
frames reset



**# Load required datasets
frame create druginfo
frame druginfo: use data/prepared/`cohort'/drugnames_clean.dta

frame copy druginfo drugnames
frame drugnames {
	keep drugname drugnamecode
	duplicates drop
}

frame create cohort
frame cohort: use patid elig* using data/prepared/`cohort'/timewindows_Q2.dta

frame create cohort2
frame cohort2: use patid elig* using data/prepared/`cohort'/timewindows_Q2_s.dta // dif dataset for sensitivity


di "$S_DATE $S_TIME"

*** Loop for all time windows
local dataset 6mpre 3mpre 1mpre 3mpost 6mpost 4mpost 1mpost 6mpre_s 3mpre_s 1mpre_s 3mpost_s 6mpost_s 4mpost_s 1mpost_s

foreach TAG of local dataset {

	di "`TAG'"

	**# Load dataset and link to get drug name (code)
	use patid prodcode start stop formulation issueseq using data/prepared/`cohort'/drugsinwindow_`TAG'.dta
	drop if formulation==10
	gen refill=(issueseq!=0)
	
	frlink m:1 prodcode, frame(druginfo)
	frget drugnamecode, from(druginfo)
	drop druginfo

	keep patid drugnamecode start stop formulation refill
	order patid drugnamecode formulation refill start stop
	
	**# Simplify the dataset by combining overlapping drugname records for the same drug
	* (records of same drug & same formulation with same start/stop date... with repeat
	* set to 1 if any otherwise duplicate records are 1)
	bys patid start stop drugnamecode formulation (refill): replace refill=refill[_N]
	duplicates drop

	*** When two records overlap, sets start date of SECOND record to start date of FIRST,
	*** then drops the FIRST record. Repeats until there are no more overlaps.
	sort patid drugnamecode formulation start stop
	by patid drugnamecode formulation: gen prevstop=stop[_n-1] if _n!=1
	count if start<=prevstop & prevstop!=.

	while `r(N)'>0 {
		by patid drugnamecode formulation: replace start=start[_n-1] if start<=prevstop & _n!=1
		bys patid drugnamecode formulation start (stop): keep if _n==_N
		
		drop prevstop
		sort patid drugnamecode formulation start stop
		by patid drugnamecode formulation: gen prevstop=stop[_n-1] if _n!=1
		count if start<=prevstop & prevstop!=.	
	}

	drop prevstop


	**# Split follow-up into distinct periods of overlapping exposure
	*	AAAAAAAAAAAAA
	*	    BBBBB		

	* Becomes

	*	AAAA
	*	    AAAAA
	*		BBBBB
	*	         AAAA

	*** Loops until there are no more overlapping records to split
	*** Important that always sort on start and stop
	sort patid start stop drugnamecode formulation
	by patid: gen tag=(_n!=1 & start<stop[_n-1] & (start!=start[_n-1] | stop!=stop[_n-1]))
	count if tag==1

	while `r(N)'!=0 {

		*** When there are overlapping records find the next DIFFERENT start date 
		*** (i.e. if two seq records have same start date, ignore & find next)
		*** If stop is before nextstart, duplicate.
		*** For original record, set stop date to nextstart
		*** For duplicate record, set start date to nextstart
		*** (i.e. splits the FIRST record into time BEFORE overlap and time during
		*** overlap.)
		sort patid start stop drugnamecode formulation
		by patid: gen nextstart=start[_n+1]
		by patid start: replace nextstart=nextstart[_N]
		gen exp=1
		replace exp=2 if nextstart<stop
		expand exp, gen(new)
		replace stop=nextstart if exp==2 & new==0
		replace start=nextstart if exp==2 & new==1
		drop nextstart exp new

		*** When there are records that start on the same day but stop on different 
		*** days, duplicate the SECOND record. For the original record, set stop to
		*** prevstop. For duplicate record, set start to prevstop.
		*** (i.e. splits the SECOND record into time during overlap and time AFTER
		*** overlap.)
		sort patid start stop drugnamecode formulation
		by patid: gen prevstart=start[_n-1]
		by patid: gen prevstop=stop[_n-1]
		gen exp=1
		replace exp=2 if start==prevstart & prevstop<stop
		expand exp, gen(new)
		replace stop=prevstop if new==0 & exp==2
		replace start=prevstop if new==1 & exp==2
		drop prevstart prevstop exp new
		
		**
		drop tag
		sort patid start stop drugnamecode formulation
		by patid: gen tag=(_n!=1 & start<stop[_n-1] & (start!=start[_n-1] | stop!=stop[_n-1]))
		count if tag==1	
	}

	**# Save this processed dataset
	drop tag
	save data/prepared/`cohort'/splitprescriptions_`TAG'.dta, replace	

	
	**# Calculate the number of different drugs during each distinct exposure period
	*** and find maximum
	*** (overall, only refill, only refill & only tablet)
	by patid start: gen count_a=_N
	by patid: egen count_a_`TAG'=max(count_a)
	
	bys patid start: egen count_b=sum(refill)
	by patid: egen count_b_`TAG'=max(count_b)
	
	gen newcount=(formulation==7 & refill==1)
	bys patid start: egen count_c=sum(newcount)
	by patid: egen count_c_`TAG'=max(count_c)
	

	**# Tidy and merge into cohort file
	keep patid count_a_`TAG' count_b_`TAG' count_c_`TAG'
	duplicates drop
	count

	frame cohort {
		frlink 1:1 patid, frame(default)
		frget *, from(default)
		drop default
	}
	
	clear
	
	*** END TAG LOOP
}


di "$S_DATE $S_TIME"




**# Different dates for sensitivity analysis so need to use cohort2 (everyone in 
*** cohort should be in cohort2 so this link should not cause problem)
frame change cohort2
frlink 1:1 patid, frame(cohort)
frget count*_s, from(cohort)
drop cohort




**# Create long datasets for each of the analyses/sensitivity analyses and combine
frame create final
frame change cohort
duplicates report patid

forval X=1/2 {
	
	frame change cohort
	if `X'==2 frame change cohort2
		
	if `X'==2 local sens "_s"
	else local sens

	frame put patid count_*3mpre`sens' count_*3mpost`sens' elig3, into(toreshape3)
	frame put patid count_*6mpre`sens' count_*6mpost`sens' elig6, into(toreshape6)
	frame put patid count_*3mpre`sens' count_*4mpost`sens' elig4, into(toreshape4)
	frame put patid count_*1mpre`sens' count_*1mpost`sens' elig1, into(toreshape1)

	foreach NUM of numlist 1 3 4 6 {
		frame toreshape`NUM' {
			keep if elig`NUM'==1
			drop elig`NUM'
			
			recode count* (.=0)
			
			foreach Y of newlist a b c {
				rename count_`Y'*pre`sens' count_`Y'_0
				rename count_`Y'*post`sens' count_`Y'_1
			}
		
			reshape long count_a_ count_b_ count_c_, i(patid) j(period)
		
			gen analysis="`NUM'`sens'"
			
			frame final: frameappend toreshape`NUM'
		}
	}
	
	
	
	
	frame drop toreshape3
	frame drop toreshape6
	frame drop toreshape4
	frame drop toreshape1

}
	
**# tidy and save
frame change final

rename analysis temp
gen analysis=1 if temp=="3"
replace analysis=2 if temp=="6"
replace analysis=3 if temp=="4"
replace analysis=4 if temp=="1"
replace analysis=5 if temp=="3_s"
replace analysis=6 if temp=="6_s"
replace analysis=7 if temp=="4_s"
replace analysis=8 if temp=="1_s"

rename count_a_ countA
label var countA "Max polypharm count all meds"

rename count_b_ countB
label var countB "Max polypharm count, only repeats"

rename count_c_ countC
label var countC "Max polypharm count, only repeats only tablets"

drop temp

save data/prepared/`cohort'/polypharmcounts.dta, replace
capture log close counts

frames reset
exit




******
capture log close counts
exit


