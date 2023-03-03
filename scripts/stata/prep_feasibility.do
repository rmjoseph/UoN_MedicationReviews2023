* 2022-03-23 Rebecca Joseph University of Nottingham
*************************************
* Name:	prep_feasibility.do
* Creator:	RMJ
* Date:	20220323
* Desc:	Estimate the number of people in elig population with med rev code in 2019
* Notes: 
* Version History:
*	Date	Reference	Update
* 20220406	new file	create file
* 20220627	prep_feasibility	tidy script
*************************************

frame create load
frame create combine

**# Get list files
local filelist: dir "data/raw/over65s/feasibility_202203" files "medrev_Define_Inc1*.txt"
display `filelist'

**# Load each file, append
foreach FILENAME of local filelist {

	frame load {
		clear
		import delim using data/raw/over65s/feasibility_202203/`FILENAME'
	}
	frame combine {
		frameappend load
	}

}

**# Keep records in 2019, drop duplicates
frame change combine
gen date=date(eventdate,"DMY")
format date %dD/N/CY

drop if date<date("01/01/2019","DMY")
drop if date>date("31/12/2019","DMY")
drop eventdate

duplicates drop patid medcode date, force


**# Load codelist
frame change load
clear
import excel "data/raw/codelists/MedicationReviews 3.xlsx", sheet("Sheet1") firstrow

frame change combine
frlink m:1 medcode, frame(load)
frget *, from(load)
drop load
recode subset (.=0)


**# First review date
bys patid (date medcode): egen firstdate=min(date)
format firstdate %dD/N/CY


**# Number of events
bys patid date: gen tag=1 if _n==1
bys patid (date): gen numevents=sum(tag)
bys patid (numevents): replace numevents=numevents[_N]


**# Denominator data (Jan 2022) - who meets entry criteria?
frame create denom
frame change denom

import delimited using "data/raw/202201_Denom/acceptable_pats_from_utspracts_2022_01.txt", stringcols(1)

frame create practice
frame practice {
	import delimited using "data/raw/202201_Denom/allpractices_JAN2022.txt", stringcols(1)
}

gen pracid = substr(patid,-5,.)

frlink m:1 pracid, frame(practice)
frget *, from(practice)
drop practice

foreach X of varlist uts lcd tod frd crd deathdate {
	rename `X' date
	gen `X' = date(date,"DMY")
	format `X' %dD/N/CY
	drop date
}

* 65+ in 2019
* 1+ year UTS data by 01/01/2019
* Still in CPRD at 01/01/2019

egen fupstart = rowmax(uts frd crd)
egen fupend = rowmin(tod lcd deathdate)
format fupstart fupend %dD/N/CY
gen age2019 = 2019-yob

count	
keep if age2019>=65
count	
keep if fupstart<=date("01/01/2018","DMY")
count	
keep if fupend>=date("01/01/2019","DMY")
count	
count if fupend==date("01/01/2019","DMY")



**# How many people in estimated eligible pop had at least 1 med rev code in 2019?
frame change combine
rename patid patid2
gen patid=string(patid2,"%15.0g"), before(patid2)

frlink m:1 patid, frame(denom)	

frame put patid, into(patlist)
frame patlist: duplicates drop

frame change denom
frlink 1:1 patid, frame(patlist)
replace patlist=(patlist<.)
tab patlist

**
frames reset
exit

