** Created by Rebecca Joseph, University of Nottingham, 27 Oct 2021
*************************************
* Name:	import_bnflabels.do
* Creator:	RMJ
* Date:	20211021	
* Desc:	Imports info derived from https://openprescribing.net/bnf/ to get bnf chapter/section/para descriptions.
* Notes: When making the .csv file, replace all spaces with normal spaces
* Version History:
*	Date	Reference	Update
* 20211021	new file	create file
* 20220301	getbnfdescfromopenpresc	Load .csv file rather than pasting manually
* 20220614	getbnfdescfromopenpresc	Rename file
* 20220622	getbnfdescfromopenpresc	Update file paths with macros
* 20220627	getbnfdescfromopenpresc	Adapt for medication reviews project
*************************************

** NEED TO RUN THIS FROM THE MASTERFILE SO ARGUMENT 'COHORT' IS DEFINED
args cohort
di "`cohort'"
**



frames reset

import delimited "data/raw/codelists/bnfchapterlabelsfromOpenPrescribing.csv", delim(",")
rename v1 code


**# separate code from description
replace code = strtrim(code)
split code, parse(":") gen(var)

**# reformat codes 1.0.0 into 010000
replace var1 = strtrim(var1)
split var1, parse(".")
replace var11 = "0" + var11
replace var11 = substr(var11,-2,2)
replace var12 = "00" + var12
replace var12 = substr(var12,-2,2)
replace var13 = "00" + var13
replace var13 = substr(var13,-2,2)
gen bnfcode = var11 + var12 + var13

**# remove excess white spaces from description
replace var2 = strtrim(var2)
replace var2 = stritrim(var2)
rename var2 bnfdesc

**# tidy
order bnfcode bnfdesc
drop code var1 var11 var12 var13
sort bnfcode

**# get chapter and section headings too
gen bnfchaptcode = substr(bnfcode,1,2)
gen bnfsectcode = substr(bnfcode,1,4)

bys bnfchaptcode (bnfcode): gen chaptdesc = bnfdesc[1]
bys bnfsectcode (bnfcode): gen sectdesc = bnfdesc[1]

**# tidy and save
compress
rename bnfdesc paragraphdesc
order bnfcode bnfchaptcode bnfsectcode paragraphdesc chaptdesc sectdesc

label var bnfcode "BNF chapter/section/paragraph in number form"
label var bnfchaptcode "BNF chapter in number form"
label var bnfsectcode "BNF chapter/section in number form"
label var paragraphdesc "paragraph of BNF label"
label var chaptdesc "chapter of BNF label"
label var sectdesc "section of BNF label"

save "data/prepared/`cohort'/bnfdescsfromopenpresc.dta", replace

clear
exit
