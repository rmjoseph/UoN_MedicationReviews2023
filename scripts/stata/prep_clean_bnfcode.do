** Created by Rebecca Joseph, University of Nottingham, 20 June 2022
*************************************
* Name:	clean_bnfcode.do
* Creator:	RMJ
* Date:	20220620	
* Desc: Define simplified drug name for every product in dictionary
* Notes:
* Version History:
*	Date	Reference	Update
* 20220620	clean_drugdictionary_gold	Separate out the bnfcode section from original
* 20220620	clean_bnfcode.do	Exclude all drugs >15 and then add specific ones back in (i.e. reverse process)
* 20220621	clean_bnfcode	Bug fix ~547 (keep 1 based on highest freq)
* 20220621	clean_bnfcode	Cut section filling missing BNF code based on formulation
* 20220622	clean_bnfcode	Update file paths with macros
* 20220623	clean_bnfcode	Update exclusion list with 9.4* and chapter 14
* 20220623	clean_bnfcode	Add: bnfcode=gold code if dmd is >15 & gold is<15
* 20220623	clean_bnfcode	Update definition check2 (simplify)
* 20220623	clean_bnfcode	Try using 8 chara rather than 6 chara code
* 20220623	clean_bnfcode	Simplify how bnfdesc is defined
* 20220627	clean_bnfcode	Adapt for medication reviews analysis
* 20220627	clean_bnfcode	Update bnf 'keep' rules with new dataset
*************************************

** NEED TO RUN THIS FROM THE MASTERFILE
args cohort
di "`cohort'"
**

set more off
frames reset

**# Load all datasets
*** Product dictionary (main frame)
use prodcode dmdcode bnfcode bnfchapter using "data/raw/stata/`cohort'_product.dta"

*** BNF codes linked with DMD codes
frame create dmdinfo
frame dmdinfo: use "data/prepared/`cohort'/bnfcodes.dta"

*** BNF labels taken from Open Prescribing (two as gets edited)
frame create openpresc
frame openpresc: use "data/prepared/`cohort'/bnfdescsfromopenpresc.dta", clear

frame create openpresc2
frame openpresc2: use "data/prepared/`cohort'/bnfdescsfromopenpresc.dta", clear

*** drug name 
frame create drug_name
frame drug_name: use "data/prepared/`cohort'/drugnames_clean.dta"




**# Start cleaning: join files together to get bnfcode for as many records as possible
*** Reshape long so one code per row
rename bnfcode origcode
split origcode, parse("/") gen(code)
rename bnfchapter origdesc
split origdesc, parse("/") gen(desc)

reshape long code desc, i(prodcode)
drop if _j>1 & code==""

compress
bys prodcode (_j): replace _j = _n	


*** Simplify the GOLD descriptions to paragraph level
gen paragraph = substr(code,1,6)
bys paragraph (code): gen paradesc = desc[1]


*** Get bnf codes from dmd linked file
frlink m:1 dmdcode, frame(dmdinfo)
frget bnf_fullcode, from(dmdinfo)
drop dmdinfo


*** BNF code is info from DMD, or from CPRD if missing
*** Convert 7 character BNF code in DMD mapped file to 8 chara code
gen temp=substr(bnf_fullcode,7,1)
gen longbnf= substr(bnf_fullcode,1,6)
replace longbnf = longbnf + "0" + temp if longbnf!=""
drop temp
replace longbnf = code if longbnf==""


*** (New 23/June/2022) If BNF code is >15 and cprd version is <15, replace
gen tag=1 if regexm(longbnf,"^1[6-9]|^[2-9]")==1
gen tag2=1 if regexm(code,"^00|^1[6-9]|^[2-9]")!=1
replace longbnf=code if tag2==1 & tag==1
drop tag2 tag


*** 6 digit code for linking with openpresc
gen bnfcode = substr(longbnf,1,6)


*** Use the info from Open Prescribing to get an updated label for each code
*** (if code doesn't exist in open presc, use label for next level up and add "Other")
*** (this requires 6 chara code)
frlink m:1 bnfcode, frame(openpresc)
frget paragraphdesc, from(openpresc)
drop openpresc

gen bnfsectcode = substr(bnfcode,1,4)

frame openpresc: drop bnfcode paragraphdesc
frame openpresc: duplicates drop

frlink m:1 bnfsectcode, frame(openpresc)
frget sectdesc, from(openpresc)
drop openpresc

gen bnfchaptcode = substr(bnfcode,1,2)

frame openpresc: drop bnfsectcode sectdesc
frame openpresc:duplicates drop

frlink  m:1 bnfchaptcode, frame(openpresc)
frget chaptdesc, from(openpresc)
drop openpresc

**** description is info from DMD
gen bnfdesc = paragraphdesc
order bnfdesc, after(bnfcode)
replace bnfdesc=paradesc if bnfdesc=="" & code==longbnf //use GOLD paragraph name if missing (23 June)

**** If missing, set description to the section description with 'Other'
replace bnfdesc = "(Other) " + sectdesc if bnfdesc==""
replace bnfdesc = "" if bnfdesc == "(Other) "

**** If missing, set description to the chapter description with 'Other'
replace bnfdesc = "(Other) " + chaptdesc if bnfdesc==""
replace bnfdesc = "" if bnfdesc == "(Other) "
sort bnfcode

****
replace bnfdesc="Unknown" if bnfcode=="000000"
replace bnfdesc="Unknown" if bnfdesc=="-"

drop paragraph paradesc paragraphdesc bnfsectcode sectdesc bnfchaptcode chaptdesc 
compress

replace bnfcode="" if bnfcode=="000000" | bnfcode=="008024"
replace longbnf="" if longbnf=="00000000" | longbnf=="00802400"

frame drop openpresc








**# IDENTIFYING THE CHAPTERS TO EXCLUDE
keep prodcode origcode origdesc bnfcode bnfdesc bnf_fullcode longbnf
duplicates drop

frlink m:1 prodcode, frame(drug_name)
frget drugname, from(drug_name)
drop drug_name

format origcode origdesc bnfdesc  %50s



*** Exclusions based on sections within BNF chapters 1-15
/*
** Exclusions based on chapters within BNF
030105 (Peak flow meters, inhaler devices and nebulisers)
060101 (06010103 only - Hypodermic equipment) (see also 59010400)
060106 (Diagnostic and monitoring devices)
// (DO NOT INCLUDE) 070302 (7.3.2.3 only: Progestogen-only contraceptives) 
070304 (Contraceptive devices)
070404 (Bladder instillations and urological surgery)
0904* (Oral nutrition)
1109* 	(Contact lenses - none)
14* (vaccines)
15*	(anaesthetics, only to be administered by suitable professional)
*/

gen check1=regexs(0) if regexm(longbnf, "^030105[0-9]+|06010103|^060106[0-9]+|^070304[0-9]+|^070404[0-9]+|^0904[0-9]+|^1109[0-9]+|^14[0-9]+|^15[0-9]+")


*** Exclusions based on chapters/codes outside the 15 standard BNF chapters
/* Keep:
- Assume that substances in 19 have been picked up by using the GOLD version
- 21.19/71.56 (oral film forming agent)
- 21.21/71.14.01 (dry mouth products)
- 21.22/71.58/71.86 (Emmolients)
- 21.23/71.52.01 (Vaginal moisturisers)
- 21.24/71.38 (Nasal products)
- 21.30/71.59 (Eye products)
- 21.34/71.53 (Vaginal PH Correction Products)
- 21.35/71.05 (Acne Treatment)
- 21.40 (Bacterial Decolonisation Products)
*/

gen check2=regexs(0) if regexm(longbnf, "^1[6-9][0-9]+|^[2-9][0-9]+")==1

replace check2="" if regexm(check2,"^2119|^212[1234]|^213[045]|^2140")==1
replace check2="" if regexm(check2,"^7105|^711401|^7138|^715[23689]|^7186")==1

gen drop=(check1!="" | check2!="")









**# SPECIFYING A SINGLE CHAPTER FOR EACH PRODCODE
*** There are records with multiple longbnf but matching bnfcode. Keep first rec
destring bnfcode, gen(numericcode)
bys prodcode numericcode (longbnf): keep if _n==1


*** Now where there are duplicates in bnfcode, count
bys prodcode (bnfcode): gen _j=_n
bys prodcode (bnfcode): egen numcodes=max(_j)

*** Find the most commonly used bnfcode per drugname
bys drugname bnfcode: gen numwithcode=_N
replace numwithcode=0 if bnfcode==""
replace numwithcode=0 if drop==1 | numericcode>=140000 // don't count the codes identified as drop==1 or in chapter 14+

*** Single prodcode may have records with missing bnfcode, drop==1, or chapter 14+, 
*** AND records with chapter 1-13. In these cases, keep the latter records.
gen exclude = (drop==1 | bnfcode=="" | numericcode>=140000)
bys prodcode: egen numexcl = sum(exclude)

count if numexcl!=numcodes & numexcl>0 // if at least one record not marked as exclude
bys prodcode (bnfcode): drop if exclude==1 & numexcl>0 & numexcl!=numcodes

drop exclude _j numcodes numexcl


** Prodcode has multiple codes, all codes are drop==1 (keep one record - doesn't matter which)
bys prodcode (bnfcode): gen _j=_n
bys prodcode: egen numcodes=max(_j)

bys prodcode: egen numdrop = sum(drop)
count if numdrop==numcodes & numdrop>1
bys prodcode (bnfcode): drop if _n>1 & numdrop==numcodes & numdrop>1

drop _j numcodes numdrop


** Prodcode has multiple codes, all codes are missing==1 (keep one record - doesn't matter which)
bys prodcode (bnfcode): gen _j=_n
bys prodcode: egen numcodes=max(_j)

gen missing=(bnfcode=="")
bys prodcode: egen nummiss = sum(missing)
count if nummiss==numcodes & nummiss>1
bys prodcode (bnfcode): drop if _n>1 & nummiss==numcodes & nummiss>1 // NONE

drop _j numcodes nummiss



** Prodcode has multiple codes, all codes are either [A] chapter 13 or less, or [B] 14 or more
** [B] has small num specific cases, easily resolved by picking one when sorted by bnfcode
bys prodcode (bnfcode): gen _j=_n
bys prodcode: egen numcodes=max(_j)

gen over14 = numericcode>=140000
bys prodcode (bnfcode): egen sumover14 = sum(over14)

bys prodcode (bnfcode): drop if _n>1 &  sumover14==2
drop _j numcodes sumover14 



** [A]? Multiple stages depending on number of codes. For 3-8 codes pick preferred code. For 2 codes, series of decisions.
bys prodcode (bnfcode): gen _j=_n
bys prodcode: egen numcodes=max(_j)

*** For numcodes >=4 there is a managable number of drugs so is possible to choose the appropriate code.
/* numcodes 7 and 8:
prednisolone "060302" (glucocorticoid therapy)
*/
gen keep = 1 if numcodes>1 & regexm(bnfcode,"060302")==1
//	(The above highlights a single row to keep based on preferred grouping. The checks make sure
//	 there is just one highlighted row per duplicated prodcode, where there are 3+ records per prodcode.)

*** for numcodes==7 or 8, all prednisolone
codebook prodcode if numcodes>=7
count if numcodes>=7 & keep==1

drop if numcodes>=7 & keep!=1


*** numcodes==5
/*** above + cyclizine, diazepam, prednisolone
cyclizine "040600" (drugs used in nausea and vertigo)
diazepam "040102" (anxiolytics)
prednisolone "060302" (glucocorticoid therapy)
*/
drop keep
gen keep = 1 if numcodes>1 & regexm(bnfcode,"040600|040102|060302")==1

codebook prodcode if numcodes==5
count if numcodes==5 & keep==1

drop if numcodes==5 & keep!=1


*** numcodes==4
/***
aspirin "020900" (antiplatelet drugs)
cyclizine hydrochloride "040652" (Drug Used In Nausea And Vertigo - Motion Sickness)
diazepam "040102" (anxiolytics)
"half-inderal la (propranolol)" "020400" 
topical corticosteroids (hydrocortisone) "130400"
hyoscine hydrobromide "040600" (drugs used in nausea and vertigo)
fluconazole "050201" (triazole antifungals)
infliximab, methotrexate "100103" (Rheumatic disease suppressant drugs)
pregabalin "040801" (control of epilepsies)
neomycin + prednisolone "110401" (Corticosteroids) ! might clash with glucocortioids
pyridoxine hydrochloride "090602" (Vitamin B group)
sodium bicarbonate "070403" (drugs used in urological pain)
*/
drop keep
gen keep = 1 if numcodes>1 & regexm(bnfcode,"020400|020900|040102|040600|040652|040801|060302|070403|090602|100103|110401|130400")==1

codebook prodcode if numcodes==4
count if numcodes==4 & keep==1

drop if numcodes==4 & keep!=1


*** numcodes==3
/* substances:
Magnesium oxide, sodium citrate "010101" (Antacids and simeticone)
hyoscine butylbromide "010200" (antispasmodics)
bisopralol, propranolol, "half-inderal la (propranolol)" "020400" (beta-adrenoceptor blocking drugs)
clonidine "020502" (Centrally acting antihypertensive drugs)
beclometasone dipropionate, budesonide "30200"	Corticosteroids (respiratory)
promethazine "030401" (antihistamines)
amitriptyline "040301" (tricyclic antideps)
chlordiazepoxide "040102" (anxiolytics)
guanfacine "040400" (BNS stimulants and drugs used for ADHD)
codeine phosphate "040702" (opioid analgesics)
pregabalin, carbamazepine, tegretol "040801" (control of epilepsies)
minocycline, doxycycline "050103" (tetracyclines)
pegasys "050303" (viral hepatitis)
mebendazole "050501" (drugs for threadworms)
prednisolone, dexamethazone "060302" (glucocorticoid therapy)
*conjugated oestrogens + medroxyprogesterone "060401"(Female sex hormones and their modulators)
tamoxifen "080304" (Hormone antagonists)
pyridoxine "090602" (Vitamin B group)
adalimumab, azathioprine, ciclosporin, methotrexate "100103" (Rheumatic disease suppressant drugs)
pyridostigmine "100201" (Drugs which enhance neuromuscular transmission)
betamethasone "110401" (corticosteroids)
prontoderm "120203" (Nasal preparations for infection) 
glucose oxidase + lactoferrin + lactoperoxidase + muramidase + sodium monofluorophosphate "120300" (Drugs acting on the oropharynx)
octenicare "130201" (Emollients)
topical corticosteroids (hydrocortisone, betamethasone) "130400"
co-cyprindiol "130602" (oral preps for acne)
iodine "131104" (chlorine and iodine)
*/
drop keep
gen keep=1 if numcodes==3 & regexm(bnfcode,"010101|010200|020400|020502|030401|040301|040102|040400|040702|040801|050103|050303|050501|060302|090602|100103|100201|110401|120203|120300|130201|130400|131104")==1

bys prodcode: egen keep2=max(keep)
replace keep=1 if numcodes==3 & keep2==. & regexm(bnfcode,"060401|030200|130602|050200|130503")==1 

codebook prodcode if numcodes==3
count if numcodes==3 & keep==1

drop if numcodes==3 & keep!=1




*** numcodes==2
*** More complicated as more examples. Algorithm approach (some arbitrary decisions rather than specifying).

*** 1.	Two codes are in same chapter/section, but one is section level and one is paragraph level
***		keep the paragraph level record
gen chapter = substr(bnfcode,1,2)
gen section = substr(bnfcode,1,4)

bys prodcode (bnfcode): gen new_j=_n
bys prodcode: egen new_numcodes=max(new_j)

bys prodcode (bnfcode): gen yes=1 if new_numcodes==2 & _n==1 & section==section[2] & regexm(bnfcode,"00$")==1

count if yes==1

drop if yes==1

drop new_j new_numcodes yes
bys prodcode (bnfcode): gen new_j=_n
bys prodcode: egen new_numcodes=max(new_j)



*** 2.	Two codes are in same chapter, but one is chapter level and other is section/paragraph level
***		keep the more detailed code
bys prodcode (bnfcode): gen yes=1 if new_numcodes==2 & _n==1 & chapter==chapter[2] & regexm(bnfcode,"0000$")==1

count if yes==1

drop if yes==1

drop new_j new_numcodes yes
bys prodcode (bnfcode): gen new_j=_n
bys prodcode: egen new_numcodes=max(new_j)



*** 3.	Base on freq of code use for each drugname (includes some examples with no drugname).
***		Keep with highest freq (no change if same freq)
bys prodcode (numwithcode bnfcode): gen yes=1 if new_numcodes==2 & _n==1 & numwithcode[1]!=numwithcode[2] // (bug fix) changed from _n==1 

count if yes==1

drop if yes==1

drop new_j new_numcodes yes
bys prodcode (bnfcode): gen new_j=_n
bys prodcode: egen new_numcodes=max(new_j)



***	4.	If the two codes are different paragraphs in same section, change code to section-level (010100)
***		Then keep one record.
bys prodcode section (bnfcode): gen sumcount = _N

codebook prodcode if sumcount==2

bys prodcode (bnfcode): drop if sumcount==2 & _n==2
replace bnfcode = section + "00" if numcodes==2 & sumcount==2
replace bnfdesc = "" if numcodes==2 & sumcount==2

drop new_j new_numcodes 
bys prodcode (bnfcode): gen new_j=_n
bys prodcode: egen new_numcodes=max(new_j)



*** 5.	Look at some of the common chapter combos or drug substances and make decisions for them
bys prodcode (bnfcode): gen combo = bnfcode[1] + " " + bnfcode[2]

/*
020504 070401 |         47        7.30        7.30
130402 131001 |         31        4.81       12.11
110301 110401 |         30        4.66       16.77
110401 120101 |         27        4.19       20.96
130404 131001 |         27        4.19       25.16
020201 020400 |         20        3.11       28.26
060501 080304 |         17        2.64       30.90
010203 040655 |         16        2.48       33.39
030401 030902 |         15        2.33       35.71
030401 030901 |         11        1.71       37.42
030902 040701 |         11        1.71       39.13
130502 130901 |         10        1.55       40.68
*/

*** 020504 070401 Alpha-adrenoceptor Blocking Drugs/Alpha-blockers (in Urinary Retention)
**** keep 020504
gen yes=1 if new_numcodes==2 & combo=="020504 070401" & bnfcode=="070401"
count if yes==1
drop if yes==1
drop yes

*** 130402 131001 Mild Topical Corticosteroids/Antibacterial Preparations Only Used Topically
**** keep 131001
gen yes=1 if new_numcodes==2 & combo=="130402 131001" & bnfcode=="130402"
count if yes==1
drop if yes==1
drop yes

*** 110301 110401 Antibacterials (in Eye Preparation)/Corticosteroids (in Eye Preparations)
**** keep 110301
gen yes=1 if new_numcodes==2 & combo=="110301 110401" & bnfcode=="110401"
count if yes==1
drop if yes==1
drop yes

*** 110401 120101 Corticosteroids (in Eye Preparations)/Drugs Acting On The Ear - Otitis Externa
**** keep 120101
gen yes=1 if new_numcodes==2 & combo=="110401 120101" & bnfcode=="110401"
count if yes==1
drop if yes==1
drop yes

drop new_j new_numcodes 
bys prodcode (bnfcode): gen new_j=_n
bys prodcode: egen new_numcodes=max(new_j)


*** 131001 (antibacterial preparations) often combined with corticosteroids, and also with acne preps. Keep antibact record.
bys prodcode (bnfcode): gen yes=1 if new_numcodes==2 & regexm(combo,"131001")==1 & bnfcode!="131001"
count if yes==1
drop if yes==1

drop new_j new_numcodes yes
bys prodcode (bnfcode): gen new_j=_n
bys prodcode: egen new_numcodes=max(new_j)


*** 030401 (antihistamines) next most common. Keep the OTHER record..
bys prodcode (bnfcode): gen yes=1 if new_numcodes==2 & regexm(combo,"030401")==1 & bnfcode=="030401"
count if yes==1
drop if yes==1

drop new_j new_numcodes yes
bys prodcode (bnfcode): gen new_j=_n
bys prodcode: egen new_numcodes=max(new_j)

*** 110301 (antibacterials) keep antibact record
bys prodcode (bnfcode): gen yes=1 if new_numcodes==2 & regexm(combo,"110301")==1 & bnfcode!="110301"
count if yes==1
drop if yes==1

drop new_j new_numcodes yes
bys prodcode (bnfcode): gen new_j=_n
bys prodcode: egen new_numcodes=max(new_j)

*** 130502 (Preparations for psoriasis) keep psoriasis record
bys prodcode (bnfcode): gen yes=1 if new_numcodes==2 & regexm(combo,"130502")==1 & bnfcode!="130502"
count if yes==1
drop if yes==1

drop new_j new_numcodes yes
bys prodcode (bnfcode): gen new_j=_n
bys prodcode: egen new_numcodes=max(new_j)

*** 040701 (Non opioids analgesics and compound products) keep this record
bys prodcode (bnfcode): gen yes=1 if new_numcodes==2 & regexm(combo,"040701")==1 & bnfcode!="040701"
count if yes==1
drop if yes==1

drop new_j new_numcodes yes
bys prodcode (bnfcode): gen new_j=_n
bys prodcode: egen new_numcodes=max(new_j)

*** 130402 (Topical corticosteroids not specified) keep OTHER record
bys prodcode (bnfcode): gen yes=1 if new_numcodes==2 & regexm(combo,"130402")==1 & bnfcode=="130402"
count if yes==1
drop if yes==1

drop new_j new_numcodes yes
bys prodcode (bnfcode): gen new_j=_n
bys prodcode: egen new_numcodes=max(new_j)

*** 010102 (Compound alginates and proprietary indigestion preparations) keep OTHER record
bys prodcode (bnfcode): gen yes=1 if new_numcodes==2 & regexm(combo,"010102")==1 & bnfcode=="010102"
count if yes==1
drop if yes==1

drop new_j new_numcodes yes
bys prodcode (bnfcode): gen new_j=_n
bys prodcode: egen new_numcodes=max(new_j)

*** 020201 (Thiazides and related diuretics) keep OTHER record
bys prodcode (bnfcode): gen yes=1 if new_numcodes==2 & regexm(combo,"020201")==1 & bnfcode=="020201"
count if yes==1
drop if yes==1

drop new_j new_numcodes yes
bys prodcode (bnfcode): gen new_j=_n
bys prodcode: egen new_numcodes=max(new_j)

*** 110401 (Corticosteroids) keep OTHER record
bys prodcode (bnfcode): gen yes=1 if new_numcodes==2 & regexm(combo,"110401")==1 & bnfcode=="110401"
count if yes==1
drop if yes==1

drop new_j new_numcodes yes
bys prodcode (bnfcode): gen new_j=_n
bys prodcode: egen new_numcodes=max(new_j)

*** 090607 (Multivitamin preparations) keep OTHER record
bys prodcode (bnfcode): gen yes=1 if new_numcodes==2 & regexm(combo,"090607")==1 & bnfcode=="090607"
count if yes==1
drop if yes==1

drop new_j new_numcodes yes
bys prodcode (bnfcode): gen new_j=_n
bys prodcode: egen new_numcodes=max(new_j)

*** 030101 (Adrenoceptor agonists) keep OTHER record
bys prodcode (bnfcode): gen yes=1 if new_numcodes==2 & regexm(combo,"030101")==1 & bnfcode=="030101"
count if yes==1
drop if yes==1

drop new_j new_numcodes yes
bys prodcode (bnfcode): gen new_j=_n
bys prodcode: egen new_numcodes=max(new_j)

*** 090402 (Enteral nutrition) keep OTHER record
bys prodcode (bnfcode): gen yes=1 if new_numcodes==2 & regexm(combo,"090402")==1 & bnfcode=="090402"
count if yes==1
drop if yes==1

drop new_j new_numcodes yes
bys prodcode (bnfcode): gen new_j=_n
bys prodcode: egen new_numcodes=max(new_j)

*** 100202 (Skeletal muscle relaxants) keep OTHER record
bys prodcode (bnfcode): gen yes=1 if new_numcodes==2 & regexm(combo,"100202")==1 & bnfcode=="100202"
count if yes==1
drop if yes==1

drop new_j new_numcodes yes
bys prodcode (bnfcode): gen new_j=_n
bys prodcode: egen new_numcodes=max(new_j)

*** 030901 (Cough suppressants) keep OTHER record
bys prodcode (bnfcode): gen yes=1 if new_numcodes==2 & regexm(combo,"030901")==1 & bnfcode=="030901"
count if yes==1
drop if yes==1

drop new_j new_numcodes yes
bys prodcode (bnfcode): gen new_j=_n
bys prodcode: egen new_numcodes=max(new_j)

*** 010902 ((Other) Drugs affecting intestinal secretions) keep OTHER record
bys prodcode (bnfcode): gen yes=1 if new_numcodes==2 & regexm(combo,"010902")==1 & bnfcode=="010902"
count if yes==1
drop if yes==1

drop new_j new_numcodes yes
bys prodcode (bnfcode): gen new_j=_n
bys prodcode: egen new_numcodes=max(new_j)



*** 6.	Few combinations left. At this point pick one record from the remaining.
bys prodcode (bnfcode): drop if _n==2

drop new_j new_numcodes 
bys prodcode (bnfcode): gen new_j=_n
bys prodcode: egen new_numcodes=max(new_j)



***	7.	Fill in bnfdesc if has been changed to missing
frlink m:1 bnfcode, frame(openpresc2)
frget paragraphdesc, from(openpresc2)
drop openpresc2

replace bnfdesc = paragraphdesc if bnfdesc==""

drop paragraphdesc





**# TIDY
sort bnfcode

*** Missing BNF code:  label the remaining missing bnfcodes "unknown"
replace bnfcode="unknown" if bnfcode==""

*** Make sure all bnfcodes have labels
bys bnfcode (bnfdesc): replace bnfdesc=bnfdesc[_N]

*** Make sure all records are labelled as 'drop' if appropriate
*** Use longbnf here
bys longbnf (drop): replace drop = drop[_N]

*** NOTE: make sure the chapters 6.1.1 and 7.3.2 are not excluded
replace drop=0 if bnfcode=="060101" & regex(origcode,"06010103")!=1
replace drop=0 if bnfcode=="070302" & regex(origcode,"07030203")!=1
**** 


*** Keep new vars
keep prodcode bnfcode bnfdesc drop longbnf
sort prodcode

destring bnfcode, gen(bnfcode_num) force


*** Get chapter name and section name for each code
frlink m:1 bnfcode, frame(openpresc2)
frget*, from(openpresc2)
drop openpresc2

gen chapter=real(substr(bnfcode,1,2))
gen section=real(substr(bnfcode,1,4))

gen miss = (chaptdesc=="")
bys chapter (miss bnfcode_num): replace chaptdesc = chaptdesc[1]
drop miss
gen miss = (sectdesc=="")
bys section (miss bnfcode_num): replace sectdesc = sectdesc[1]
drop miss

replace chaptdesc = "Incontinence Appliances" if chapter==22
replace chaptdesc = "Stoma Appliances" if chapter==23

replace sectdesc = chaptdesc + " (other)" if sectdesc=="" & chaptdesc!=""
replace sectdesc = bnfdesc if sectdesc==""
bys section (bnfcode_num): replace sectdesc = sectdesc[1]
bys chapter (bnfcode_num): replace chaptdesc = sectdesc[1] if chaptdesc==""


label var drop "1 if check1==1 or check2==1"
label variable bnfcode_num "Numerical form of BNF chapter code, missing leading 0 for chapt <10"
label variable chapter "BNF chapter (numerical form)"
label variable section "BNF section (numerical form)"
label variable bnfdesc "BNF heading at paragraph level"
label variable bnfcode "New paragraph-level bnfcode"
label variable longbnf "BNF code full length (subparagrah)"
rename drop drop_bnf


*** end
save "data/prepared/`cohort'/bnfchapters_clean.dta", replace

frames reset
exit




