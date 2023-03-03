* Created by Rebecca Joseph, University of Nottingham, 2022-03-01
*************************************
* Name:	import_bnfsnomedmap.do
* Creator:	RMJ
* Date:	20220301	
* Desc: Imports BNF/Snomed mapping file from TRUD. Formats variables. 
* Notes:
* Version History:
*	Date	Reference	Update
* 20220301	new file	Moved from dmd_preparation.do script
* 20220614	BNFtoSNOMEDLookup.do	Rename file
* 20220622	import_bnfsnomedmap	Update file paths with macros
* 20220627	import_bnfsnomedmap	Adapt for medication reviews project
*************************************

** NEED TO RUN THIS FROM THE MASTERFILE SO ARGUMENT 'COHORT' IS DEFINED
args cohort
di "`cohort'"


frames reset
import excel "data/raw/codelists/BNF Snomed Mapping data 20220617.xlsx", sheet("April 2022") firstrow allstring

rename BNFCode bnf_fullcode
rename BNFName bnf_name
rename VMPVMPPAMPAMPP sourcefile
rename DMDProductDesc dmd_name
rename DMDProductandPack dmd_packname
rename Strength bnf_strength
destring bnf_strength, replace
rename UnitOfMeasure bnf_units
replace bnf_units = "" if bnf_units=="UNKNOWN"
replace bnf_units = "" if bnf_units=="no value"

rename SNOMEDCode dmdcode

sort bnf_fullcode sourcefile
drop if bnf_fullcode==""

count if dmdcode==""
drop if dmdcode==""

duplicates report dmdcode

order bnf_fullcode bnf_name bnf_strength bnf_units dmdcode sourcefile dmd_name
keep bnf_fullcode - dmd_name
compress

format bnf_name dmd_name %60s

save "data/prepared/`cohort'/bnfcodes.dta", replace

frames reset
exit
