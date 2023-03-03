** Created 2022-05-19 by Rebecca Joseph, University of Nottingham
*************************************
* Name:	prep_importcodelists.do
* Creator:	RMJ
* Date:	20220519	
* Desc:	Imports Read code lists from excel to single lookup
* Notes: 
* Version History:
*	Date	Reference	Update
* 20220519	new file	create file
* 20220520	prep_importcodelists	Add strtrim to medical dictionary so oxmis codes link
* 20220530	prep_importcodelists	Add medrev to list of codes
* 20220831	prep_importcodelists	Change to v2. Add falls fractures prostate, drop urinaryret urinaryinc.
*************************************

frames reset 

**# Local macro containing names of all excel sheets with code lists in
#delimit ;
local allvars 
	medrev
	alcohol
	ethnicity
	smoking
	anxiety
	asthma
	atrialfib
	bipolar
	cancer
	carehome
	chronkid
	copd
	coronaryhd
	dementia
	depression
	diabetes
	dyslipidaemia
	epilepsy
	falls
	famhypchol
	fractures
	glaucoma
	gout
	heartfail
	hypertension
	hypothyroidism
	learningdis
	lipidtests
	mentalhealth
	mi
	mobilityproblem
	obesity
	osteoporosis
	palliativecare
	parkinsons
	periphart
	prostate
	rheumatoidarth
	schizophrenia
	sevfrailty
	stroke
	thrombophilia
	thrombosis
	tia
	stroketia
	urinarycont ;

#delimit cr
di "`allvars'"


**# Import each list from lookup, keeping category info where present. Combine into single long list.
frame change default
clear
frame create impcodes

foreach X of local allvars {
frame impcodes {
	clear
	import excel data/raw/codelists/MedRev_allcodelists_v2.xlsx, sheet(`X') case(lower) allstring
	drop if _n==1
	rename A readcode
	drop B
	capture rename C `X'_c
	drop if readcode==""
	duplicates drop
	duplicates drop readcode, force

	gen `X'=1
	}
frameappend impcodes
}

replace readcode=strtrim(readcode)

**# Readcodes may be in multiple lists. Collapse where there are multiple records per Readcode.
sort readcode
foreach X of local allvars {
	bys readcode (`X'): replace `X'=`X'[1]
	capture bys readcode (`X'_c): replace `X'_c=`X'_c[1]
	}
	
duplicates drop
sort readcode

**# Get medcode and description from medical lookup
frame create medical
frame medical {
 import delim data/raw/Lookups_2022_05/medical.txt
 replace readcode=strtrim(readcode)
}

frlink 1:1 readcode, frame(medical)
frget *, from(medical)
order medcode readcode desc

drop medical

**# Save
save data/prepared/ad/codelists_lookup.dta, replace
save data/prepared/over65s/codelists_lookup.dta, replace

frames reset
exit
