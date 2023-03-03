* Created by Rebecca Joseph, University of Nottingham, 2022-06-14
*************************************
* Name:	clean_dmdformulation.do
* Creator:	RMJ
* Date:	20220614	
* Desc: Takes DMD route/formulation info from downloaded TRUD files to create
*		single route and formulation for each vmp code.
* Notes:
* Version History:
*	Date	Reference	Update
* 20220614	dmd_preparation	Separate file for parts specific to formulation/route
* 20220615	clean_dmdformulation	Change formulation classifications to match simpler groups used elsewhere
* 20220620	clean_dmdformulation	Rename form_main dmd_form
* 20220620	clean_dmdformulation	Create numerical version of dmd_form
* 20220622	clean_dmdformulation	Update file paths with macros
* 20220627	clean_dmdformulation	Apapt for medication review project
*************************************

** NEED TO RUN THIS FROM THE MASTERFILE
args cohort
di "`cohort'"
**



** Formulation information in ontological form files and unit of measure.
** ontform and uom need to be linked via dmdcode.

frames reset

frame create ONTFORM
frame ONTFORM: use "data/prepared/`cohort'/dmd_form_raw.dta"

frame create VMP
frame VMP {
	use vmpid vmp_name dose_uom unit_uom using "data/prepared/`cohort'/dmd_information.dta"
	duplicates drop
	rename vmpid dmdcode
}


**# Clean formulation/route data to end up with a single row for each dmdcode
frame change ONTFORM

*** Start by simplifying existing routes/forms into fewer categories
duplicates tag dmdcode, gen(tag)
sort dmdcode route form

*** Route
gen newroute=""
replace newroute="injection" if regexm(route,"intraarterial|intraarticular|intramuscular|intravenous|subcutaneous")==1 & newroute==""
replace newroute="topical" if regexm(route,"auricular|cutaneous|inhalation|iontophoresis|nasal|ocular|opthalmic|ophthalmic|scalp|transdermal|urethral|vaginal")==1 & newroute==""
replace newroute="oral" if regexm(route,"^oral")==1 & newroute==""
replace newroute="mouth_other" if regexm(route,"buccal|dental|gingival|oromucosal|sublingual")==1 & newroute==""
replace newroute="enteral_other" if regexm(route,"gastroenteral|^rectal")==1 & newroute==""
replace newroute="parent_other" if route=="peribulbar ocular" | route=="intraocular"
replace newroute="parent_other" if newroute==""

bys newroute: tab route_dmd,m sort


*** Formulation
gen newform=""
replace newform="other" if regexm(formulation,"implant$|device|system|ring")==1 & newform==""
replace newform="other" if regexm(formulation,"enema")==1 & newform==""
replace newform="other" if regexm(formulation,"pessary")==1 & newform==""
replace newform="food" if regexm(formulation,"food|grocery|tea$")==1 & newform==""
replace newform="other" if regexm(formulation,"suppository")==1 & newform==""
replace newform="drops" if regexm(formulation,"drops")==1 & newform==""
replace newform="spray" if regexm(formulation,"spray")==1 & newform==""
replace newform="other" if regexm(formulation,"paint")==1 & newform==""

replace newform="injected" if newroute=="injection" & newform==""
replace newform="injected" if newroute=="parent_other" & newform==""

replace newform="other" if newroute=="enteral_other" & regexm(formulation,"cream|ointment")==1 & newform==""
replace newform="other" if newroute=="enteral_other" & newform==""

replace newform="tablets" if newroute=="oral" & regexm(form,"capsule|pillule|tablet")==1 & newform==""
replace newform="other" if newroute=="oral" & regexm(form,"granules|powder")==1 & newform==""
replace newform="other" if newroute=="oral" & regexm(form,"film|lyophilisate")==1 & newform==""
replace newform="other" if newroute=="oral" & regexm(form,"lozenge|pastille")==1 & newform==""
replace newform="unspec liquid" if newroute=="oral" & newform==""

replace newform="other" if newroute=="mouth_other" & regexm(form,"film|lyophilisate")==1 & newform==""
replace newform="creams/topical" if newroute=="mouth_other" & regexm(formulation,"gel|ointment|paste")==1 & newform==""
replace newform="tablets" if newroute=="mouth_other" & regexm(form,"capsule|pillule|tablet")==1 & newform==""
replace newform="other" if newroute=="mouth_other" & regexm(form,"granules|powder")==1 & newform==""
replace newform="other" if newroute=="mouth_other" & regexm(form,"lozenge|pastille|gum$")==1 & newform==""
replace newform="spray" if newroute=="mouth_other" & regexm(form,"vapour")==1 & newform==""
replace newform="unspec liquid" if newroute=="mouth_other" & newform==""

replace newform="patches" if newroute=="topical" & regexm(form,"patch")==1 
replace newform="inhaled" if newroute=="topical" & regexm(form,"nebuliser|inhalation")==1 
replace newform="creams/topical" if newroute=="topical" & regexm(form,"cream|emulsion|gel|ointment|paste|poultice")==1 
replace newform="tablets" if newroute=="topical" & regexm(form,"capsule|tablet")==1 & newform==""
replace newform="other" if newroute=="topical" & regexm(form,"collodion|lacquer")==1 & newform==""
replace newform="other" if newroute=="topical" & regexm(form,"insert")==1 & newform==""
replace newform="other" if newroute=="topical" & regexm(form,"foam")==1 & newform==""
replace newform="other" if newroute=="topical" & regexm(form,"cigarette|stick|strip")==1 & newform==""
replace newform="device dressing or garment" if newroute=="topical" & regexm(form,"dressing|plaster")==1 & newform==""
replace newform="other" if newroute=="topical" & regexm(form,"powder")==1 & newform==""
replace newform="unspec liquid" if newroute=="topical" & newform==""




*** Drop duplicates based on these new categories
drop formulation_dmd route_dmd tag
sort dmdcode newform newroute
duplicates drop
duplicates report dmdcode
duplicates tag dmdcode, gen(tag)



*** With simplified categories, some still have multiple records. 
*** Use info from VMP file to help select single option.

*** Reshape wide
sort dmdcode newroute newform
bys dmdcode (newroute newform): gen j=_n
reshape wide newroute newform, i(dmdcode) j(j)
order dmdcode newroute* newform*

*** Route/form with no conflicts
sort newroute1 newroute2 vmp_name
gen route_main = newroute1 if tag==0
replace route_main = newroute1 if tag==1 & newroute1==newroute2
replace route_main = newroute1 if tag==2 & newroute1==newroute2 & newroute1==newroute3

gen form_main = newform1 if tag==0
replace form_main = newform1 if tag==1 & newform1==newform2
replace form_main = newform1 if tag==2 & newform1==newform2 & newform1==newform3


*** Selecting single form for case with 5 options
replace route_main = "topical" if tag==4
replace form_main = "other" if tag==4


*** Selecting single form when there are multiple options
sort dose_uom

replace form_main="tablets" if form_main=="" & (dose_uom=="capsule" | dose_uom=="tablet")
replace form_main="other" if form_main=="" & (dose_uom=="sachet" )

sort dose_uom vmp_name

replace form_main="unspec liquid" if form_main=="" & (dose_uom=="ml" )
replace form_main="unspec liquid" if form_main=="" & (dose_uom=="vial" )

sort newform1 newform2

replace form_main="food" if form_main=="" & newform1=="food" | newform2=="food"
replace form_main="drops" if form_main=="" & newform1=="drops"
replace form_main="creams/topical" if form_main=="" & newform1=="creams/topical"
replace form_main="inhaled" if form_main=="" & newform1=="inhaled"
replace form_main="creams/topical" if form_main=="" & newform2=="creams/topical"
replace form_main="unspec liquid" if form_main=="" & (newform2=="unspec liquid")

replace form_main="other" if form_main=="" 


*** Selecting single route when there are multiple options
order dmdcode route_main form_main
sort newroute1 newroute2

replace route_main="injection" if route_main=="" & newroute1=="enteral_other" & newroute2=="injection"
replace route_main="topical" if route_main=="" & newroute1=="enteral_other" & newroute3=="topical"
replace route_main="oral" if route_main=="" & newroute1=="enteral_other" & newroute2=="oral"
replace route_main="topical" if route_main=="" & newroute1=="enteral_other" & form_main=="creams/topical"
replace route_main="enteral_other" if route_main=="" & newroute1=="enteral_other"
replace route_main="injection" if route_main=="" & newroute1=="injection"
replace route_main="oral" if route_main=="" & newroute1=="mouth_other" & newroute2=="oral"
replace route_main="topical" if route_main=="" & form_main=="spray"
replace route_main="topical" if route_main=="" & form_main=="creams/topical"
replace route_main="topical" if route_main==""

*** Create indicators for multiple routes/forms (highlights where there were conflicts)
gen multipleroutes=(newroute1!=newroute2 & newroute2!="")
gen multipleforms=(newform1!=newform2 & newform2!="") | (newform1!=newform3 & newform3!="")

*** Amend some of the less-specific formulations based on route
sort route_main form_main 

replace form_main="injected" if route_main=="injection" & form_main=="unspec liquid"


*** Tidy dataset
keep dmdcode route_main form_main multipleroutes multipleforms
order dmdcode route_main form_main multipleroutes multipleforms
sort dmdcode






**# LINK ONTFORM TO VMP and fill in missing formulations
frame change VMP
frlink 1:1 dmdcode, frame(ONTFORM)
frget*, from(ONTFORM)
gen noforminfo = (ONTFORM==.)
drop ONTFORM

*** Fill in remaining missing formulations using unit of measure fields or vmp_name
sort dose_uom unit_uom

replace form_main = "tablets" if noforminfo==1 & (dose_uom=="tablet" | dose_uom=="capsule") & form_main==""
replace form_main = "other" if noforminfo==1 & (dose_uom=="sachet") & regexm(vmp_name,"powder|granules")==1 & form_main==""
replace form_main = "drops" if noforminfo==1 & regexm(vmp_name,"drops")==1 & form_main==""
replace form_main = "device dressing or garment" if noforminfo==1 & regexm(vmp_name,"suture|dressing|gauze|lint|felt|swabs|sling|plaster|collar|bandage|corn rings|bunion rings")==1 & form_main==""
replace form_main = "inhaled" if noforminfo==1 & regexm(vmp_name,"inhal")==1 & form_main==""
replace form_main = "creams/topical" if noforminfo==1 & regexm(vmp_name,"cream|ointment|lotion")==1 & form_main==""
replace form_main = "other" if noforminfo==1 & dose_uom=="ml" & unit_uom=="enema" & form_main==""
replace form_main = "unspec liquid" if noforminfo==1 & dose_uom=="ml" & unit_uom!="unit dose" & form_main==""

replace form_main = "tablets" if noforminfo==1 & form_main=="" & regexm(vmp_name,"tablet|capsule")==1
replace form_main = "other" if noforminfo==1 & form_main=="" & regexm(vmp_name,"pessary")==1
replace form_main = "spray" if noforminfo==1 & form_main=="" & regexm(vmp_name,"spray")==1
replace form_main = "unspec liquid" if noforminfo==1 & form_main=="" & regexm(vmp_name,"liquid|solution|suspension")==1
replace form_main = "other" if noforminfo==1 & form_main=="" & regexm(vmp_name,"powder")==1
replace form_main = "other" if noforminfo==1 & form_main=="" & regexm(vmp_name,"paint|lacquer")==1

replace form_main = "other" if noforminfo==1 & form_main=="" & dose_uom=="pessary"
replace form_main = "patches" if noforminfo==1 & form_main=="" & dose_uom=="patch"
replace form_main = "other" if noforminfo==1 & form_main=="" & dose_uom=="pastille"
replace form_main = "other" if noforminfo==1 & form_main=="" & dose_uom=="lozenge"
replace form_main = "other" if noforminfo==1 & form_main=="" & dose_uom=="suppository"
replace form_main = "other" if noforminfo==1 & form_main=="" & dose_uom=="enema"
replace form_main = "other" if noforminfo==1 & form_main=="" & dose_uom=="actuation"
replace form_main = "other" if noforminfo==1 & form_main=="" & dose_uom=="application"
replace form_main = "unspec liquid" if noforminfo==1 & form_main=="" & dose_uom=="litre"
replace form_main = "unspec liquid" if noforminfo==1 & form_main=="" & dose_uom=="vial"
replace form_main = "creams/topical" if noforminfo==1 & form_main=="" & dose_uom=="applicator"

replace form_main = "device dressing or garment" if noforminfo==1 & form_main=="" & regexm(vmp_name,"garment|stocking|dressing|bandage|gauze|ostomy|[Ss]uture|stockinette|[Cc]atheter|cement|tape|truss|[sS]toma")==1



**# Tidy and save
keep dmdcode route_main form_main multipleroutes multipleforms noforminfo
sort dmdcode

rename form_main dmd_form
rename route_main dmd_route

replace dmd_form = "unknown" if dmd_form==""
replace dmd_form = "nondrug" if regexm(dmd_form,"device|food" )==1

gen dmd_form_num=.
replace dmd_form_num=1 if dmd_form=="drops"
replace dmd_form_num=2 if dmd_form=="spray"
replace dmd_form_num=3 if dmd_form=="inhaled"
replace dmd_form_num=4 if dmd_form=="injected"
replace dmd_form_num=5 if dmd_form=="creams/topical"
replace dmd_form_num=6 if dmd_form=="patches"
replace dmd_form_num=7 if dmd_form=="tablets"
replace dmd_form_num=8 if dmd_form=="unspec liquid"
replace dmd_form_num=9 if dmd_form=="other"
replace dmd_form_num=10 if dmd_form=="nondrug"

label define unitform 1 "drops" 2 "spray" 3 "inhaled" 4 "injected" 5 "creams/topical" 6 "patches" 7 "tablets" 8 "unspec liquid" 9 "other" 10 "non-drug" , modify

label values dmd_form_num unitform


save "data/prepared/`cohort'/dmd_form_clean.dta", replace




****
frames reset
exit



