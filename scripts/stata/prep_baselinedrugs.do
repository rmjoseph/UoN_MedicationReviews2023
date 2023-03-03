* Created 7 July 2022 by Rebecca Joseph, University of Nottingham
*************************************
* Name:	prep_baselinedrugs.do
* Creator:	RMJ
* Date:	20220707	
* Desc: Use the active prescriptions at index date to define whether specific
*		drug groups were prescribed, and which BNF chapters were prescribed.
* Notes: 
* Version History:
*	Date	Reference	Update
* 20220707	new file	DRAFT FILE CREATED
* 20220712	prep_baselinedrugs	Prefix the bnf flags b_ instead so can distinguish
* 20220712	prep_baselinedrugs	Add anticholinergics
* 20220720	prep_baselinedrugs	Load drugsinwindow_6mpre rather than _index
* 20220720	prep_baselinedrugs	Drop if formulation==non-drug
* 20220720	prep_baselinedrugs	Remove section calculating presc count
* 20220722	prep_baselinedrugs	change drugsinwindow file from 6mpre (is wrt MR not index)
* 20220825	prep_baselinedrugs	Add "indacaterol" & others to inhaled beta agonists
* 20220825	prep_baselinedrugs	Add sep search term for aspirin in antiplatelets
* 20220825	prep_baselinedrugs	Add cleaning section to remove incorrect terms
* 20220825	prep_baselinedrugs	For benzos, use drug list rather than BNF chapters
* 20220929	prep_baselinedrugs	Exclude testing strips from anticoag using formulation
* 20220929	prep_baselinedrugs	Exclude pentosan from anticoag
* 20220929	prep_baselinedrugs	Change aspirin search so doesn't capture combos
* 20220929	prep_baselinedrugs	Include drug names in opioids search to capture combos
* 20220929	prep_baselinedrugs	New variable for gabapentinoids
* 20220929	prep_baselinedrugs	Take oxazepam and remimazolam from benzos search
* 20220930	prep_baselinedrugs	Update list of ACh drugs
* 20220930	prep_baselinedrugs	Add extra rules for ACh drugs to eg exclude drops
* 20220930	prep_baselinedrugs	Exclude prochlorperazine from antipsych
* 20221003	prep_baselinedrugs	Process BNF vars in new frame using index dataset
* 20230302	prep_baselinedrugs	Tidy file
*************************************

** NEED TO RUN THIS FROM THE MASTERFILE SO ARGUMENT 'COHORT' IS DEFINED
args cohort
di "`cohort'"


**# Load datasets.
frames reset

*** drugs in 6m before index
use patid prodcode formulation using data/prepared/`cohort'/drugsinwindow_index_min6.dta	
drop if formulation==10 // drop if formulation is non-drug
duplicates drop

*** Drugs on index date (for baseline BNF chapters)
frame create BNF
frame BNF {
	use patid prodcode formulation using data/prepared/`cohort'/drugsinwindow_index.dta
	drop if formulation==10 // drop if formulation is non-drug
	drop formulation
	duplicates drop
}

*** Drug name/chapter info
frame create drugs
frame drugs {
	use prodcode drugname using data/prepared/`cohort'/drugnames_clean.dta
	merge 1:1 prodcode using data/prepared/`cohort'/bnfchapters_clean.dta, keepusing(bnfcode_num chapter) keep(3) nogen
}




**# Combine datasets
foreach X of newlist default BNF {
	
	frame `X' {
		frlink m:1 prodcode, frame(drugs)
		frget *, from(drugs)

		drop prodcode
		duplicates drop

		}
}



**# Identify specific drugs groups at baseline
gen d_nsaids=(bnfcode_num==100101)

gen d_anticoag=(bnfcode_num==20802) & formulation!=.
replace d_anticoag=0 if regexm(drugname,"pentosan")==1
replace d_anticoag=0 if formulation==10|formulation==.

gen d_antiplate=(bnfcode_num>=20900 & bnfcode_num<21000)|drugname=="aspirin"
gen d_reninang=(bnfcode_num==20505)
gen d_diuretics=(bnfcode_num>=20200 & bnfcode_num<20300)
gen d_opioids=(bnfcode_num==40702)|regexm(drugname,"dihydrocodeine|codeine|dextropropoxyphene")==1
gen d_antidep=(bnfcode_num>=40300 & bnfcode_num<40400)
gen d_antipsych=(bnfcode_num==40201 | bnfcode_num==40202)
replace d_antipsych=0 if regexm(drugname,"prochlorperazine")==1

gen d_bisphos=(bnfcode_num==60602)
gen d_benzod=regexm(drugname,"alprazolam|chlordiazepoxide|clobazam|clonazepam|diazepam|flurazepam|loprazolam|lorazepam|lormetazepam|midazolam|nitrazepam|temazepam|zolpidem|zopiclone")==1
gen d_gabapentinoid=regexm(drugname,"pregabalin|gabapentin")==1

gen d_inhaled=regexm(drugname,"eformoterol|eformoterol|salmeterol|indacaterol|olodaterol|bambuterol|vilanterol")==1|(bnfcode_num>=30200 & bnfcode_num<30300)
replace d_inhaled=0 if formulation!=3

gen d_lithium=regexm(drugname,"lithium")==1

*** Anticholinergic drugs (list from Coupland 2019 https://doi.org/10.1001/jamainternmed.2019.0677)
#delimit ;
local achlist 
disopyramide
amitriptyline
amoxapine
clomipramine
desipramine
doxepin
imipramine
nortriptyline
paroxetine
protriptyline
trimipramine
prochlorperazine
promethazine
pyrilamine
triprolidine
brompheniramine
carbinoxamine
chlorpheniramine
clemastine
cyproheptadine
dexbrompheniramine
dexchlorpheniramine
dimenhydrinate
diphenhydramine
doxylamine
hydroxyzine
meclizine
clidinium-chlordiazepoxide
dicyclomine
homatropine
hyoscyamine
methscopolamine
propantheline
darifenacin
fesoterodine
flavoxate
oxybutynin
solifenacin
tolterodine
trospium
benztropine
trihexyphenidyl
chlorpromazine
clozapine
loxapine
olanzapine
perphenazine
thioridazine
trifluoperazine
atropine
belladonna
scopolamine
cyclobenzaprine
orphenadrine
dosulepin
lofepramine
cyclizine
dimenhydrinate
promazine
azatadine
chlorphenamine
trimeprazine
alimemazine
propiverine
benzatropine
orphenadrine
methotrimeprazine
levomepromazine
pericyazine
perphenazine
pimozide
quetiapine
alverine
dicyclomine
dicycloverine
propantheline
hyoscine
carbamazepine
oxcarbazepine
methocarbamol
tizanidine
glycopyrrolate
glycopyrronium
ipratropium;
#delimit cr
gen d_ach = 0
foreach X of local achlist {
	replace d_ach=1 if regexm(drugname,"`X'")==1
}
replace d_ach=0 if form==1
replace d_ach=0 if regexm(drugname,"diphenhydramine")==1 & form!=7


*** Turn drug flags into indicators
keep patid d_*
duplicates drop

foreach X of varlist d_* {
	bys patid (`X'): replace `X'=`X'[_N]
	local name = substr("`X'",3,.)
	label var `X' "Prescribed `name' in 6m up to & including index"
}

duplicates drop


**# Identify bnf chapters at baseline
frame BNF {
	gen b_bnf1=chapter==1
	gen b_bnf2=chapter==2
	gen b_bnf3=chapter==3
	gen b_bnf4=chapter==4
	gen b_bnf5=chapter==5
	gen b_bnf6=chapter==6
	gen b_bnf7=chapter==7
	gen b_bnf8=chapter==8
	gen b_bnf9=chapter==9
	gen b_bnf10=chapter==10
	gen b_bnf11=chapter==11
	gen b_bnf12=chapter==12
	gen b_bnf13=chapter==13
	gen b_bnf99=chapter>=14
	
	keep patid b_*
	
	foreach X of varlist b_* {
		bys patid (`X'): replace `X'=`X'[_N]
		local name = substr("`X'",6,.)
		label var `X' "Active prescription BNF chapter `name' on index"
	}
	
	duplicates drop
}



*** Combine
sort patid
frlink 1:1 patid, frame(BNF)
frget *, from(BNF)
drop BNF

frame BNF {
	frlink 1:1 patid, frame(default)
	keep if default==.
	drop default 
	count
}

if `r(N)'>0 frameappend BNF
recode d_* b_* (.=0)

duplicates drop


**# Save
save data/prepared/`cohort'/baselinedrugs.dta, replace



exit
