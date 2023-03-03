** Created by RMJ, University of Nottingham, 22 Aug 2022
*************************************
* Name:	test_estdur.do
* Desc:	Use to test the script 'estdur.do' using fake data. First parts tested 
*		by inserting 'list' into estdur, rest looking at the output or 
*		working through the code.
* Notes: 
* Version History:
*	Date	Reference	Update
*	20220629	test_estdur First set up
*************************************

** Program to easily reset the dataset
capture program drop CHANGEFRAME
program define CHANGEFRAME
	frame change default
	capture frame drop testing
	frame copy raw testing
	frame change testing
end


** Code to allow data to be pasted into editor
capture frame create raw
frame change raw
clear
edit // (paste in test dataset)
gen eventdate=date(date,"DMY")
format eventdate %dD/N/CY
drop date


// Test `if' condition
/*
patid	prodcode	date	consid	issueseq	dosekey	qty	daily_dose	numdays	dose_duration	prn
1	1	01/01/2020	1	1	1	28	1	30	7	
1	1	01/01/2020	1	1	1	28	1	30	7	
1	1	29/01/2020	2	2	1	28	1	30		
1	1	27/02/2020	3	3	1	28	1	45	7	
1	1	20/03/2020	4	0	1	28	1			
1	1	18/04/2020	5	1	1	28	1	30		
1	1	18/05/2020	6	2	1	28	1		28	
1	1	18/05/2020	7	3	1	28	1			
1	1	18/05/2020	8	4	1	28	1		30	
1	1	25/08/2020	9	1	1	28	1			
*/
CHANGEFRAME
estdur if patid==10

// Test duplicates drop
CHANGEFRAME
estdur

CHANGEFRAME
estdur, keepdups

// Test duplicates on same day keep/drop
CHANGEFRAME
estdur, keepdups dropsameday

// Test repeat prescription durations
CHANGEFRAME
estdur

// Cleaning qty ndd, durations
CHANGEFRAME
estdur, maxdur(20)
/*
patid	prodcode	date	consid	issueseq	dosekey	qty	daily_dose	numdays	dose_duration	prn
1	2	01/01/2020	1	0	2	28	1	7	30	1
1	2	27/02/2020	2	0	2	5	7	7		1
1	2	20/03/2020	3	0	2	5	1			
1	2	18/04/2020	4	0	2	5	1		30	1
1	2	18/05/2020	5	0	2	5	1			
1	2	25/08/2020	6	0	2	5	600			1
1	2	25/09/2020	7	0	2	500	0			1
*/





// Choosing duration vars
/*
duration2	duration3	duration4	finaldur
			
		8	
	6		
4			
4		8	
	6	8	
4	6		
	34	8	
3	3	4	
4	5	5	
6	4	6	
4	4	4	
4	6	8	
1	3	2	
20	50	80	
4	6	12	
4	16	8	
2	6	8	
10	40	100		
*/
frame change raw
clear
edit // (paste in test dataset)

CHANGEFRAME

*** CODE
egen nonmiss = rownonmiss(duration2 duration3 duration4)
egen avg = rowmean(duration2 duration3 duration4)
replace avg = floor(avg)

gen dif23 = abs(duration2 - duration3)
gen dif24 = abs(duration2 - duration4)
gen dif34 = abs(duration4 - duration3)

egen mindif = rowmin(dif23 dif24 dif34)
egen meddif = rowmedian(dif23 dif24 dif34)	// 3 values so == mode if 2+ are equal

local maxdifference 20
replace mindif = . if mindif > `maxdifference'

** one non-missing
replace finaldur=avg if finaldur==. & nonmiss==1

** two non-missing
replace finaldur=avg if finaldur==. & nonmiss==2 & mindif<.

** any two (or three) equal, use that value
replace finaldur=duration2 if finaldur==. & nonmiss>1 & duration2==duration3
replace finaldur=duration2 if finaldur==. & nonmiss>1 & duration2==duration4
replace finaldur=duration3 if finaldur==. & nonmiss>1 & duration3==duration4

** three non-missing, evenly spaced
replace finaldur=avg if finaldur==. & nonmiss==3 & mindif<. & mindif==meddif

** three non-missing, two values closer than third
replace finaldur=floor((duration2 + duration3)/2) if finaldur==. & nonmiss==3 & mindif<. & dif23==mindif
replace finaldur=floor((duration2 + duration4)/2) if finaldur==. & nonmiss==3 & mindif<. & dif24==mindif
replace finaldur=floor((duration3 + duration4)/2) if finaldur==. & nonmiss==3 & mindif<. & dif34==mindif
	
	
	








// Test avg duration, pop or pat level
/*
patid	prodcode	date	consid	issueseq	dosekey	qty	daily_dose	numdays	dose_duration	prn
1	1	01/01/2020	1	0	1	0	0		5	
1	1	01/02/2020	1	0	1	0	0			
1	2	01/03/2020	1	0	1	0	0			
1	2	01/04/2020	1	0	1	0	0			
2	1	01/01/2020	1	0	1	0	0		10	
2	1	01/02/2020	1	0	1	0	0			
2	2	01/03/2020	1	0	1	0	0		10	
2	2	01/04/2020	1	0	1	0	0			
*/
CHANGEFRAME
estdur

CHANGEFRAME
estdur, bypat







// Test multiple prescs same day
/*
patid	prodcode	eventdate	quantity	finaldur
1	1	0	20	20
1	1	0	20	20
1	1	0	20	20
1	1	0	20	20
1	1	0	20	20
1	1	40	20	20
*/
frame change raw
clear
edit // (paste in test dataset)

CHANGEFRAME

*** ESTDUR CODE
gen start = eventdate
gen stop = start + finaldur

sort patid prodcode eventdate // `prescseq'
by patid prodcode eventdate: egen summed_qty=sum(quantity)
by patid prodcode eventdate: gen num_recs=_N
by patid prodcode eventdate: egen newdur=sum(finaldur)
by patid prodcode eventdate: keep if _n==1

**** set this new variable to maxduration if it is >maxduration
local maxduration 100
replace newdur=`maxduration' if newdur>`maxduration'
replace stop = start + newdur

* works, may end up with records longer than the subsequent records






// Test truncating overlaps
/*
patid	prodcode	prescseq	start	stop	newdur
1	1	1	0	30	30
1	1	2	15	45	30
1	1	3	30	60	30
1	1	4	40	50	10
1	1	5	45	75	30
1	1	6	80	110	30
1	1	7	115	145	30
1	1	8	140	160	20
1	1	9	180	200	20
1	1	10	199	220	21
*/
frame change raw
clear
edit // (paste in test dataset)

CHANGEFRAME

*** CODE
**** Number of days overlap of two records A and B, attach to A
sort patid prodcode prescseq

by patid prodcode: gen nextstart=start[_n+1] if _n!=_N
by patid prodcode: gen prevstop=stop[_n-1] if _n!=1
*format nextstart prevstop %dD/N/CY
gen truncated = stop - nextstart
replace truncated=. if truncated<=0		

**** Truncate record A (stop of A becomes start of B)
replace stop=nextstart if truncated<.
replace newdur = stop - start		

**** Make identifier for a run of continuous prescs
gen new=1 if start > prevstop
by patid prodcode: gen newid=sum(new)

**** Sum the number of truncated days within each continuous run of prescriptions
sort patid prodcode newid start
by patid prodcode newid: gen sumt=sum(truncated)

**** If the number of truncated days is greater than specified number... 
**** ... replace with that number
local overlap 30
replace sumt=`overlap' if sumt>`overlap' & sumt<.

**** Add the number of truncated days to the last day of the run of prescs
by patid prodcode newid: replace newdur=newdur + sumt if _n==_N
replace stop = start + newdur		

**** This can introduce new overlaps so truncate records once more
drop nextstart prevstop truncated

by patid prodcode: gen nextstart=start[_n+1] if _n!=_N
by patid prodcode: gen prevstop=stop[_n-1] if _n!=1
*format nextstart prevstop %dD/N/CY
gen truncated = stop - nextstart
replace truncated=. if truncated<=0	

replace stop = nextstart if truncated<.
replace newdur = stop - start

**** Check for outstanding overlaps
by patid prodcode: gen newoverlap = start<stop[_n-1] & _n>1
qui sum newoverlap

if `r(max)'!=0 {
	di as error "There are still overlaps in this dataset - review"
	exit
}





// Test code for gaps between records
/* 
patid	prodcode	start	stop	newdur
1	1	0	10	10
1	1	15	25	10
1	1	25	35	10
1	1	50	60	10
1	1	60	70	10
*/
frame change raw
clear
edit // (paste in test dataset)

CHANGEFRAME

**** code:
*** Gaps between prescriptions: fill in up to max, truncate new overlaps
sort patid prodcode start
*tempvar nextstart prevstop gap newoverlap truncated

**** Identify and find length of gaps
by patid prodcode: gen nextstart=start[_n+1] if _n!=_N
by patid prodcode: gen prevstop=stop[_n-1] if _n!=1
*format nextstart prevstop %dD/N/CY

gen gap = nextstart - stop
replace gap=0 if gap==.		

**** If gap is greater than maxgap, set to 0 (so stop doesn't change)
local maxgap 15
replace gap=0 if gap>`maxgap'

**** Add the gap to the stop date
replace newdur = newdur + gap
replace stop = start + newdur

**** If this has created overlaps, truncate
drop nextstart prevstop 

by patid prodcode: gen nextstart=start[_n+1] if _n!=_N
by patid prodcode: gen prevstop=stop[_n-1] if _n!=1
*format nextstart prevstop %dD/N/CY
gen truncated = stop - nextstart
replace truncated=. if truncated<=0

replace stop=nextstart if truncated<.
replace newdur = stop - start

**** Check for outstanding overlaps
by patid prodcode: gen newoverlap = start<stop[_n-1] & _n>1
qui sum newoverlap

if `r(max)'!=0 {
	di as error "There are still overlaps in this dataset - review"
	exit
}




// FINAL CHECK
/*
patid	prodcode	date	consid	issueseq	dosekey	qty	daily_dose	numdays	dose_duration	prn
1	1	01/01/2020	1	1	1	28	1			
1	1	01/01/2020	1	1	1	28	1			
1	1	30/01/2020	2	2	1	2	5	28		
1	1	02/03/2020	3	3	1	2	5		28	
1	1	01/04/2020	4	4	1	28	1	28		
1	1	01/04/2020	4	5	1	28	1		28	
1	1	29/05/2020	4	6	1	28	1	60		
1	1	15/07/2020	7	7	1	28	1	30	7	
1	2	01/01/2020	1	0	1	0	0			
1	2	30/01/2020	2	0	1	0	0			
1	2	02/03/2020	3	0	1	28	1			
1	3	01/04/2020	4	0	1	2	5			
1	4	01/04/2020	4	1	1	15	1	7	10	1
1	4	01/05/2020	5	2	1	15	1	7	37	1
1	4	10/05/2020	6	3	1	15	1	7		1
1	5	29/05/2020	7	0	1	15	1			1
2	2	01/01/2020	1	0	1	10	1			
2	3	01/02/2020	2	0	1	7	1			
2	3	05/02/2020	3	0	1	7	1			
2	3	13/02/2020	4	0	1	7	1			
2	3	22/02/2020	5	0	1	7	1			
2	3	30/03/2020	6	0	1	7	1			
*/
capture frame create raw
frame change raw
clear
edit // (paste in test dataset)

gen eventdate=date(date,"DMY")
format eventdate %dD/N/CY
drop date

**
CHANGEFRAME
estdur
sort patid prodcode start

CHANGEFRAME
estdur, keepdups
sort patid prodcode start
bro patid prodcode issueseq start stop

CHANGEFRAME
estdur, dropsameday
sort patid prodcode start
bro patid prodcode issueseq start stop

CHANGEFRAME
estdur, maxdur(30)
sort patid prodcode start
bro patid prodcode issueseq start stop

CHANGEFRAME
estdur, dropqty	
sort patid prodcode start
bro patid prodcode issueseq start stop

CHANGEFRAME
estdur, prndefault(7)	
sort patid prodcode start
bro patid prodcode issueseq start stop

CHANGEFRAME
estdur, default(10)	
sort patid prodcode start
bro patid prodcode issueseq start stop

CHANGEFRAME
estdur, bypat
sort patid prodcode start
bro patid prodcode issueseq start stop

CHANGEFRAME
estdur, bypat default(10)
sort patid prodcode start
bro patid prodcode issueseq start stop

CHANGEFRAME
estdur, overlap(5)
sort patid prodcode start
bro patid prodcode issueseq start stop

CHANGEFRAME
estdur, maxgap(0)
sort patid prodcode start
bro patid prodcode issueseq start stop

CHANGEFRAME
estdur, maxdif(100)
sort patid prodcode start
bro patid prodcode issueseq start stop

// All checks are ok. (Not exactly the same: summed_qty and num_recs show works.)
/* This is because:
The extra dates will overlap with next record. Overlap will be added and then
truncated. So the final dates look the same. This is how it is meant to work.
*/


frames reset
exit

