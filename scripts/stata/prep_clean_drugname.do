** Created by Rebecca Joseph, University of Nottingham, 20 June 2022
*************************************
* Name:	clean_drugname.do
* Creator:	RMJ
* Date:	20220620	
* Desc: Define simplified drug name for every product in dictionary
* Notes:
* Version History:
*	Date	Reference	Update
* 20220620	clean_drugdictionary_gold	Separate out the drug name section from original
* 20220620	clean_drugname	Move definition of drugname after all cleaning steps
* 20220622	clean_drugname	Update file paths with macros
* 20220627	clean_drugname	Adapt for medication reviews project
*************************************

** NEED TO RUN THIS FROM THE MASTERFILE
args cohort
di "`cohort'"
**

set more off
frames reset


**# Load and prepare product dataset in main frame
use prodcode dmdcode productname drugsubstance using "data/raw/stata/`cohort'_product.dta"

replace productname = lower(productname)
replace productname = strtrim(productname)
replace productname = stritrim(productname)

replace drugsubst = lower(drugsubst)
replace drugsubst = strtrim(drugsubst)
replace drugsubst = stritrim(drugsubst)

format drugsubst productname %50s



**# load dmd info to get vtm_name
frame create dmdinfo
frame dmdinfo: use dmdcode vtm_name using "data/prepared/`cohort'/dmd_information.dta"
frlink m:1 dmdcode, frame(dmdinfo)
frget *, from(dmdinfo)
gen hasdmdinfo=dmdinfo<.
drop dmdinfo
format vtm_name %50s



**# START CLEANING - drug substance, vtm_name
gen origdrugsub=drugsubstance
format origdrugsub %50s


*** remove any apostrophes
replace drugsubstance = subinstr(drugsubstance,"'","",.)


*** remove info in brackets
forval x=1/2 {
	split drugsubstance, parse("(") gen(t1_) limit(2)
	format t1* %30s
	split t1_2, parse(")") gen(t2_)
	replace t2_1 = "(" + t2_1 + ")"
	replace drugsubstance = subinstr(drugsubstance,t2_1,"",.)
	drop t1_* t2_*
}

replace drugsubstance = strtrim(drugsubstance)
replace drugsubstance = stritrim(drugsubstance)

sort drugsubstance vtm_name


*** other punctuation
replace drugsubstance = subinstr(drugsubstance,",","",.)
replace drugsubstance = subinstr(drugsubstance,`"""',"",.)
replace drugsubstance = subinstr(drugsubstance,"+","and",.)
replace drugsubstance = subinstr(drugsubstance,":","",.)


*** encoding errors
replace drugsubstance = subinstr(drugsubstance,"ÃÂ®","e",.)
replace drugsubstance = subinstr(drugsubstance,"Ã©","e",.)



*** Where multiple substances are present, change so listed alphabetically and separated by a "+"
split drugsubstance, parse("/") gen(tempdrug)

reshape long tempdrug, i(prodcode)
drop if tempdrug=="" & _j>1
sort prodcode tempdrug
bys prodcode (tempdrug): replace _j=_n

reshape wide

egen combined = concat(tempdrug*), punct("  ")
replace combined = strrtrim(combined)
replace combined = subinstr(combined,"  "," + ",.)

replace drugsubstance = combined
drop combined tempdrug* 

format drugsubstance %50s
sort drugsubstance


*** Clean vtm_name so that multiple substances (if present) are sorted alphabetically
split vtm_name, parse(" + ") gen(tempdrug)

reshape long tempdrug, i(prodcode)
drop if tempdrug=="" & _j>1
sort prodcode tempdrug
bys prodcode (tempdrug): replace _j=_n

reshape wide

egen combined = concat(tempdrug*), punct("  ")
replace combined = strrtrim(combined)
replace combined = subinstr(combined,"  "," + ",.)

replace vtm_name = combined
drop combined tempdrug* 

format vtm_name %50s
sort drugsubstance vtm_name





**# CLEANING PRODUCTNAME
gen origprodname = productname
format origprodname %50s
replace productname = "" if vtm_name!="" & drugsubstance!=""

format productname %50s
replace productname = lower(productname)
replace productname = subinstr(productname,"'","",.) // removing apostrophes
replace productname = strtrim(productname)
replace productname = stritrim(productname)


*** Remove supplier/manufacturer details
**** Identify "(text)" at end of string
gen full = regexs(0) if regexm(productname,"\(.+\)")==1	// any info in brackets (will find longest poss)
format full %50s

gen tag = regexs(0) if regexm(productname,"\([a-z.,&: \/\+\-]+\)$")==1	//"(any letter or space,.&:+-/)"
order full productname tag
sort tag
bys tag: gen n=_n
replace productname = subinstr(productname,tag,"",.)	// replace instances of "tag" with """
replace productname = strtrim(productname)
replace productname = stritrim(productname)

gen tagX=tag
drop tag n

**** specific fields not picked up above
replace productname = subinstr(productname,"(365 healthcare ltd)","",.)
replace productname = subinstr(productname,"(3m health care ltd)","",.)
replace productname = subinstr(productname,"(4c health ltd)","",.)
replace productname = subinstr(productname,"(healthcare 2000 ltd)","",.)
replace productname = subinstr(productname,"(healthcare 21)","",.)
replace productname = subinstr(productname,"(a1 pharmaceuticals)","",.)
replace productname = subinstr(productname,"(victoria pharmaceuticals) (special order)","",.)
replace productname = subinstr(productname,"(general dietary ltd)","",.)
replace productname = subinstr(productname,"(gluten free)","",.)
replace productname = subinstr(productname,"(kci medical ltd)","",.)
replace productname = subinstr(productname,"(nestle clinical nutrition)","",.)
replace productname = subinstr(productname,"(abbott nutrition)","",.)
replace productname = subinstr(productname,"(acerola cherry)","",.)
replace productname = subinstr(productname,"(nutricia ltd)","",.)
replace productname = subinstr(productname,"(roc laboratoires uk ltd)","",.)

replace productname = strtrim(productname)
replace productname = stritrim(productname)

**** identify nested parentheses..."(text(text)text)"
gen tag = regexs(0) if regexm(productname,"\([a-z,&. \-]*\([a-z.& ]+\)[a-z ]*\)")==1
order full productname tag
sort tag
bys tag: gen n=_n
replace tagX=tag if tagX==""

replace productname = subinstr(productname,tag,"",.)
replace productname = strtrim(productname)
replace productname = stritrim(productname)

drop tag n

*** remove any other details in parentheses (repeat as some have 2 brackets)
forval X=1/4 {
	gen tag = regexs(0) if regexm(productname,"\(.+\)")==1
	order full productname tag
	sort tag
	bys tag: gen n=_n

	split tag, parse(") ")	// if string has >1 set brackets e.g. "text (text) text (text)" split
	replace tag1 = tag1 + ")" if regexm(tag1,"\)$")!=1 & tag1!=""	// add ")" if string was split

	replace productname = subinstr(productname,tag1,"",.)
	replace productname = strtrim(productname)
	replace productname = stritrim(productname)

	drop tag n tag1 
	capture drop tag4
	capture drop tag3
	capture drop tag2
}
drop full


*** Most product names are in the format product 00dose	- can split if there's a number
replace productname="10-10 15 ml sol" if origprodname=="10.10 15 ml sol"

replace productname=regexr(productname," [0-9]|\.[0-9]","!")
replace productname = strtrim(productname)
replace productname = stritrim(productname)

split productname, parse("!") gen(new) limit(2)
order productname new*
format new* %50s

replace new1=subinstr(new1," .","",.) // if was a decimal e.g. .25

replace productname = new1 if new1!=""
drop new1 new2 tag

replace productname = strtrim(productname)
replace productname = stritrim(productname)


*** Remove formulation details
gen tag=""

replace tag = regexs(0) if regexm(productname," tab$| cap$| crm$| sol$| eye$| ear$| lot$| cre$| liq$| pow$| oin[t]*$| spa$| dro$| pas$| gel$| sup$| spr$| inj$| syr$| s\/r$| sus$| aer$| loz$| s\/f$| lin$| mix$")==1

replace tag = regexs(0) if regexm(productname," implant$| tablets$| drops$| capsules$| cream$| nose$| liquid$| spray$| pastilles$| mouthwash$| sachet[s]*$| ampoules$| spacer$| salve$| paste$| syrup$| lozenge$| patch[es]*$| solution$")==1	// not powder

order productn tag
sort tag
bys tag: gen n=_n

replace productname = subinstr(productname,tag,"",.)
replace productname = strtrim(productname)
replace productname = stritrim(productname)

drop tag n

**** repeat
gen tag = regexs(0) if regexm(productname," mouth$| nasal$| eye$| ear\/eye\/nose$| vaginal$| foot$| topical$| cleansing$| hand$| foot & heel$| body$| drops$| oint$| barrier film$| aerosol$| throat$| tincture$| sunburn$| barrier$| soothing$| homeopathic$| oral$| soluble$| paste$| liq$| ml$| mg$| moisuturising$| cream$| masking$| night$| emollient$| daily$")
order productn tag
sort tag
bys tag: gen n=_n
replace productname = subinstr(productname,tag,"",.)
replace productname = strtrim(productname)
replace productname = stritrim(productname)
drop tag n

**** repeat again
gen tag = regexs(0) if regexm(productname," foam$| nasal$| day &$| super$")
order productn tag
sort tag
bys tag: gen n=_n
replace productname = subinstr(productname,tag,"",.)
replace productname = strtrim(productname)
replace productname = stritrim(productname)
drop tag n



*** Remove 'generic' at start of products
gen tag = regexs(0) if regexm(productname,"generic")==1
order productname tag
replace productname = subinstr(productname,tag,"",.)
replace productname = strtrim(productname)
replace productname = stritrim(productname)
drop tag



*** Convert / to +, sort alphabetically
**** first remove some of the extra / that might cause problems (focusing on drugs)
replace productname=regexr(productname," ear\/eya| ear\/eye| b\/a| b\/a| i\/v| m\/f| e\/c| p\/f| s\/f| click\/count| i\/u^2| c\/r| u\/c| oral\/im\/iv| cfc\/free| s\/r","")

**** then split, reshape, sort, reshape
replace productname = subinstr(productname,"/"," + ",.)
replace productname = subinstr(productname,"&"," + ",.)
replace productname = stritrim(productname)
split productname, parse(" + ") gen(tempdrug)

reshape long tempdrug, i(prodcode)
drop if tempdrug=="" & _j>1
sort prodcode tempdrug
bys prodcode (tempdrug): replace _j=_n

reshape wide

egen combined = concat(tempdrug*), punct("  ")
replace combined = strrtrim(combined)
replace combined = subinstr(combined,"  "," + ",.)

replace productname = combined
drop combined tempdrug* 

format productname %50s
sort drugsubstance vtm_name





**# DEFINE DRUGNAME BASED ON THE CLEANED VARIABLES
*** Create drugname = vtm_name
gen drugname = lower(vtm_name)


*** If  missing, use drug substance
replace drugname = lower(drugsubstance) if drugname=="" & drugsubstance!="" 
sort drugname prodcode
format drugname %50s

*** Use cleaned productname if drugname is still missing. Make an indicator so can remove these at later stage.
gen prodname=1 if drugname=="" & productname!=""
replace drugname = productname if drugname==""

*** before continue, recode some of the combination products
replace drugname = "aspirin + codeine" if regexm(drugname,"co-codaprin")
replace drugname = "codeine + paracetamol" if regexm(drugname,"co-codamol")
replace drugname = "dextropropoxyphene + paracetamol" if regexm(drugname,"co-proxamol")
replace drugname = "dihydrocodeine tartrate + paracetamol" if regexm(drugname,"co-dydramol")
replace drugname = "methionine + paracetamol" if regexm(drugname,"co-methiamol")




**# TIDY AND SAVE, creating a numeric version of the drugname variable
keep prodcode dmdcode drugname prodname
label var drugname "Drug substance from DMD or GOLD if avail, otherwise simplified productname"
label var prodname "1 if drugname is based on productname"
sort prodcode

replace drugname = "" if drugname=="zz"
replace drugname = "" if drugname=="unknown"

encode drugname, gen(drugnamecode)
label drop drugnamecode
compress
format drugnamecode %9.0g
sort prodcode
label values drugnamecode .

compress

label variable drugnamecode "Numerical identifier for each drug substance (link back to new lookup for name)"


*** save
sort prodcode
save "data/prepared/`cohort'/drugnames_clean.dta", replace

frames reset

exit
