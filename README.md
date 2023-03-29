# UoN_MedicationReviews2023
Stata do-files for preparation and analysis of CPRD data for a project about medication reviews recorded in UK primary care in 2019.

## Introduction
This repository contains all the Stata do-files and code lists required to reproduce results from an analysis describing access to and impact of medication reviews in UK primary care. The data were anonymised health records from England and were provided under licence from CPRD and cannot be shared. For more information see https://www.cprd.com/. The code and information provided in this repository detail all data manipulation and analysis, from data extraction to exporting results.

The work includes analyses from two separate CPRD projects, the first investigating medication reviews in people aged 65 years or older, and the second investigating medication reviews in people prescribed antidepressants. The same process was applied to both projects (referred to throughout the code as 'over65s' and 'ad'). The 'master script' details the order scripts were run and it is possible to separate the process for the two projects.

The projects, including the protocols and the Stata code in this repository, were designed and written by researchers at the University of Nottingham. The projects were funded by the National Institute for Health and Care Research (NIHR) School for Primary Care Research (project reference 587) and the NIHR Nottingham Biomedical Reserch Centre. Any views expressed are those of the author(s) and not necessarily those of the NIHR or the Department of Health and Social Care. This code underpins all of the results of this study, including those presented in published works, and has been shared for purposes of transparency and reproducibility.

We request that any use of or reference to the Stata code within this repository is cited appropriately using the information provided on its Zenodo entry (https://doi.org/10.5281/zenodo.7738103).

## Using the files
### Data
The data were provided under licence by the Clinical Practice Research Datalink (over65s: CPRD GOLD dataset May 2022, ad: CPRD GOLD dataset Nov 2020). The queries used to define primary care data are provided within the documentation/ directory. The file **'directory structure and raw files list.docx'** explains the directory structure and raw files needed for the code to run without modification. The source of each raw file is detailed in this document.

Codelists and lookup tables created for the project are provided (data/raw/codelists/). No raw or processed CPRD or linked files are included in this repository. 

### Stata information
This project was performed using Stata/MP v17. Reuse requires at least Stata 16 as the frames function is used throughout. The following Stata packages are required:
- frameappend (ssc install frameappend)
- splitvallabels (ssc install splitvallabels)
- grc1leg (net install grc1leg, from("http://www.stata.com/users/vwiggins/"))
- cleanplots (net install cleanplots, from("https://tdmize.github.io/data/cleanplots"))

### Running the code
- The file 'scripts/stata/scripts_masterfile.do' should be used to run the analysis. The path to the working directory must be set at **line 30**. All other scripts use relative paths.
