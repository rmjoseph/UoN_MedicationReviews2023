** Created 2022-04-06 by Rebecca Joseph, University of Nottingham
*************************************
* Name:	prep_ad_importlookups.do
* Creator:	RMJ
* Date:	20220406	
* Desc:	Loads lookup files from polypharm dir and saves in current dir
* Notes: 
* Version History:
*	Date	Reference	Update
* 20220406	new file	create file
* 20220520	prep_ad_importlookups	Rename directory antidepressant_data (former) to ad (new)
* 20220530	prep_ad_importlookups	Also load and save Staff file
* 20220627	prep_ad_importlookups	Change file paths; add common_dosages import
* 20230303	prep_ad_importlookups	Update file path for sharing
*************************************

** clear memory
set more off
frames reset

**# Load and save
clear
import delim using "data/raw/Lookups_2020_11/medical.txt"
save data/raw/ad/medical.dta, replace

clear
import delim using "data/raw/Lookups_2020_11/product.txt", stringcol(2)
save data/raw/ad/product.dta, replace
save data/raw/stata/ad_product.dta, replace

clear
import delim using "data/raw/Lookups_2020_11/common_dosages.txt"
save data/raw/stata/ad_common_dosages.dta, replace

clear
import delim using "data/raw/Lookups_2020_11/TXTFILES/COT.txt"
save data/raw/ad/constype.dta, replace

clear
import delim using "data/raw/Lookups_2020_11/TXTFILES/ROL.txt"
save data/raw/ad/staffrole.dta, replace

clear
import delim using "data/raw/ad/gold_patid1_Extract_Staff_001.txt", stringcol(1)
save data/raw/stata/ad_Staff.dta, replace

*************************************
frames reset
exit
