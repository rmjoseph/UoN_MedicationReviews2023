* Created by Rebecca Joseph, University of Nottingham, 2022-06-14
*************************************
* Name:	import_dmdinfo.do
* Creator:	RMJ
* Date:	20220614	
* Desc: Loads and combines the DMD files downloaded from TRUD. 
*		Saves two files for later use.
* Notes:
* Version History:
*	Date	Reference	Update
* 20220614	dmd_preparation	Rename file
* 20220622	import_dmdinfo	Update file paths with macros
* 20220627	import_dmdinfo	Adapt for medication reviews project
*************************************

** NEED TO RUN THIS FROM THE MASTERFILE SO ARGUMENT 'COHORT' IS DEFINED
args cohort
di "`cohort'"

/* FILES NEEDED:
*	uom	extracteddmd20210904/dmdDataLoader/csv/f_lookup_UoMHistoryInfoType.csv
*	ontform	extracteddmd20210904/dmdDataLoader/csv/f_lookup_OntFormRouteInfoType.csv
*	ontform lookup	extracteddmd20210904/dmdDataLoader/csv/f_vmp_OntDrugFormType.csv
*	vmp	extracteddmd20210904/dmdDataLoader/csv/f_vmp_VmpType.csv
*	amp	extracteddmd20210904/dmdDataLoader/excel/f_amp.xlsx
*	vtm	extracteddmd20210904/dmdDataLoader/excel/f_vtm.xlsx
*/

frames reset

********* PART 1 - load all files
**# Unit of measure
frame create UOM

frame UOM {
	import delimited "data/raw/dmd_20210830/f_lookup_UoMHistoryInfoType.csv", stringcols(_all) 
	rename v1 uom1
	rename v2 date
	rename v3 uom2
	rename v4 uom_name
	sort uom_name uom1

	*** reshape long to create single variable uom associated with a use from date
	gen i=_n
	reshape long uom, i(i)
	sort i _j
	drop if uom==""

	gen uom_useduntil = date(date, "YMD") if _j==2
	gen uom_usedfrom = date(date,"YMD") if _j==1
	format uom_used* %dD/N/CY

	keep uom*
	sort uom

	duplicates report uom
}



**# ontological form (two files needed to get key)
*** File 1 is the formulation and route info assoc with each ontcode
frame create ONTFORM1
frame ONTFORM1 {
	import delimited "data/raw/dmd_20210830/f_lookup_OntFormRouteInfoType.csv", stringcols(_all) 
	rename v1 ontcode
	split v2, parse(".")
	rename v21 formulation_dmd
	rename v22 route_dmd
	drop v2
}
	
*** File 2 is the link between vmpid and ontcode
frame create ONTFORM2
frame ONTFORM2 {
	import delimited "data/raw/dmd_20210830/f_vmp_OntDrugFormType.csv", stringcols(_all) 
	rename v1 vmpid
	rename v2 ontcode
}

*** combine the two files
frame ONTFORM2 {
	frlink m:1 ontcode, frame(ONTFORM1)
	frget *, from(ONTFORM1)
	drop ONTFORM1 ontcode
}



**# VMP
frame create VMP

frame VMP {
	
	import delimited "data/raw/dmd_20210830/f_vmp_VmpType.csv", stringcols(_all) 

	*** Label and format variables, drop variables
	rename v1 vmpid1
	rename v2 date
	rename v3 vmpid2
	rename v4 vtmid
	rename v5 vmp_invalid
	destring vmp_invalid, replace

	rename v6 vmp_name
	rename v7 vmp_abbrevname

	rename v13 vmp_combination
	destring vmp_combination, replace
	label define combo 0 "Not combination" 1 "Combination pack" 2 "Only available in combination"
	label values vmp_combination combo

	rename v21 vmp_doseformind
	destring vmp_doseformind, replace
	label define doseformind 1 "Discrete" 2 "Continuous" 3 "NA"
	label values vmp_doseformind doseformind

	rename v22 vmp_unitdoseformsize
	destring vmp_unitdoseformsize, replace

	rename v23 uom // unit dose form size unit of measure
	rename v24 uom2 // unit dose unit of measure

	drop v8-v12
	drop v14-v20


	*** Reshape long so each vmpid (including the historical ones) is included
	sort vmp_name vmpid1
	gen i=_n
	reshape long vmpid, i(i)
	sort i _j
	drop if vmpid==""

	gen vmp_useduntil = date(date, "YMD") if _j==2
	gen vmp_usedfrom = date(date,"YMD") if _j==1

	format vmp_used* %dD/N/CY

	
	*** Finalise
	drop i _j date
	order vmpid vmp_useduntil vmp_usedfrom
	format vmp_name vmp_abbrevname %50s

	duplicates tag vmpid, gen(tag)
	sort vmpid vmp_useduntil
	bys vmpid (vmp_useduntil): keep if _n==1
	drop tag

	keep vmpid vmp_name uom uom2 vtmid
}


**# AMP
frame create AMP
frame AMP {
	import excel "data/raw/dmd_20210830/f_amp.xlsx", sheet("AmpType") firstrow allstring

	rename APID ampid
	rename INVALID amp_invalid
	destring amp_invalid, replace
	rename VPID vmpid
	rename NM amp_name
	format amp_name %60s
	rename ABBREVNM amp_abbrevname
	format amp_abbrevname %60s
	rename DESC amp_desc
	format amp_desc %60s

	keep ampid vmpid amp_name
}


**# VTM
frame create VTM
frame VTM {
	
	import excel "data/raw/dmd_20210830/f_vtm.xlsx", ///
	sheet("VTM") firstrow allstring
	rename VTMID vtmid1
	rename VTMIDPREV vtmid2

	*** reshape long to get all vtmids and their use dates
	sort NM vtmid1
	gen i=_n
	reshape long vtmid, i(i)

	sort i _j
	drop if vtmid==""

	gen vtm_useduntil = date(VTMIDDT, "YMD") if _j==2
	gen vtm_usedfrom = date(VTMIDDT,"YMD") if _j==1

	format vtm_useduntil vtm_usedfrom %dD/N/CY
	drop VTMIDDT

	*** rename other vars
	rename NM vtm_name
	rename ABBREVNM vtm_abbrevname
	rename INVALID vtm_invalid

	order vtmid vtm_invalid vtm_name vtm_abbrevname vtm_usedfrom vtm_useduntil
	drop i _j vtm_abbrevname

	*** Check for duplicates
	duplicates tag vtmid, gen(tag)
	drop if vtmid=="412096001" & vtm_name=="Co-codaprin"
		
}


********* PART 2 - Create dmd lookup file with dmdcode ampid vmpid vtmid vtm_name vmp_name and unit of measure info
**# LINK VMP and AMP and VTM. Make dmdcode variable using amp and vmp.
*** vmp and uom
frame VMP {
	
	frlink m:1 uom, frame(UOM)
	frget *, from(UOM)
	drop uom UOM uom_used*
	rename uom_name dose_uom

	rename uom2 uom
	frlink m:1 uom, frame(UOM)
	frget *, from(UOM)
	drop uom UOM uom_used*
	rename uom_name unit_uom

}

*** vmp and vtm
frame VMP {
	
	sort vtmid
	frlink m:1 vtmid, frame(VTM)
	frget *, from(VTM)
	gen novtm = (VTM==.)
	drop VTM

}


*** amp and vmp
frame change AMP
gen dmdcode=ampid
gen source="AMP"

order dmdcode, first

frlink m:1 vmpid, frame(VMP)
frget *, from(VMP)
count if VMP==.
drop VMP

*** Append VMP so lookup has full list of dmdcodes
frameappend VMP
replace dmdcode = vmpid if dmdcode==""
replace source="VMP" if source==""

*** Tidy and save file
order dmdcode ampid vmpid vtmid source vtm_name vmp_name amp_name dose_uom unit_uom
keep  dmdcode ampid vmpid vtmid source vtm_name vmp_name amp_name dose_uom unit_uom

save "data/prepared/`cohort'/dmd_information.dta", replace




********* PART 3 - Combine form/route info for further processing
frame VMP {
	keep vmpid vmp_name dose_uom unit_uom
	duplicates drop
}

frame ONTFORM2 {
	frlink m:1 vmpid, frame(VMP)
	frget *, from(VMP)
	drop VMP
}

frame change ONTFORM2
rename vmpid dmdcode

save "data/prepared/`cohort'/dmd_form_raw.dta", replace



frames reset
exit
