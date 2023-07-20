*=========================================================================*
* GLOBAL LEARNING ASSESSMENT DATABASE (GLAD)
* Project information at: https://github.com/worldbank/GLAD
*
* Metadata to be stored as 'char' in the resulting dataset (do NOT use ";" here)
local region      = "RWA"   /* LAC, SSA, WLD or CNT such as KHM RWA */
local year        = "2018"  /* 2015 */
local assessment  = "EGRA" /* PIRLS, PISA, EGRA, etc */
local master      = "v01_M" /* usually v01_M, unless the master (eduraw) was updated*/
local adaptation  = "wrk_A_GLAD" /* no need to change here */
local module      = "ALL"  /* for now, we are only generating ALL and ALL-BASE in GLAD */
local ttl_info    = "Joao Pedro de Azevedo [eduanalytics@worldbank.org]" /* no need to change here */
local dofile_info = "last modified by Domenica Avila 23.6.2022"  /* change date*/
*
* Steps:
* 0) Program setup (identical for all assessments)
* 1) Open all rawdata, lower case vars, save in temp_dir
* 2) Combine all rawdata into a single file (merge and append)
* 3) Standardize variable names across all assessments
* 4) ESCS and other calculations
* 5) Bring WB countrycode & harmonization thresholds, and save dtas
*=========================================================================*



  *---------------------------------------------------------------------------
  * 0) Program setup (identical for all assessments)
  *---------------------------------------------------------------------------

  // Parameters ***NEVER COMMIT CHANGES TO THOSE LINES!***
  //  - whether takes rawdata from datalibweb (==1) or from indir (!=1), global in 01_run.do
  local from_datalibweb = $from_datalibweb
  //  - whether checks first if file exists and attempts to skip this do file
  local overwrite_files = $overwrite_files
  //  - optional shortcut in datalibweb
  local shortcut = "$shortcut"
  //  - setting random seed at the beginning of each do for reproducibility
  set seed $master_seed

  // Set up folders in clone and define locals to be used in this do-file
  glad_local_folder_setup , r("`region'") y("`year'") as("`assessment'") ma("`master'") ad("`adaptation'")
  local temp_dir     "`r(temp_dir)'"
  local output_dir   "`r(output_dir)'"
  local surveyid     "`r(surveyid)'"
  local output_file  "`surveyid'_`adaptation'_`module'"

  // If user does not have access to datalibweb, point to raw microdata location
  if `from_datalibweb' == 0 {
    local input_dir	= "${glad_input}/CNT/`region'/`region'_`year'_`assessment'/`surveyid'/Data/Stata"
  }

  // Confirm if the final GLAD file already exists in the local clone
  cap confirm file "`output_dir'/`output_file'.dta"
  // If the file does not exist or overwrite_files local is set to one, run the do
  *if (_rc == 601) | (`overwrite_files') {

    /* Filter the master country list to only this assessment-year - Not necessary for country-level EGRAs
    use "${clone}/01_harmonization/011_rawdata/master_countrycode_list.dta", clear
    keep if (assessment == "`assessment'") & (year == `year')
    // Most assessments use the numeric idcntry_raw but a few (ie: PASEC 1996) have instead idcntry_raw_str
    if use_idcntry_raw_str[1] == 1 {
      drop   idcntry_raw
      rename idcntry_raw_str idcntry_raw
    }
    keep idcntry_raw national_level countrycode
    save "`temp_dir'/countrycode_list.dta", replace
	*/

    // Tokenized elements from the header to be passed as metadata
    local glad_description  "This dataset is part of the Global Learning Assessment Database (GLAD). It contains microdata from `assessment' `year'. Each observation corresponds to one learner (student or pupil), and the variables have been harmonized."
    local metadata          "region `region'; year `year'; assessment `assessment'; master `master'; adaptation `adaptation'; module `module'; ttl_info `ttl_info'; dofile_info `dofile_info'; description `glad_description'"

    *---------------------------------------------------------------------------
    * 1) Open all rawdata, lower case vars, save in temp_dir
    *---------------------------------------------------------------------------
set seed 10051990
set sortseed 10051990

    /* NOTE: Some assessments will loop over `prefix'`cnt' (such as PIRLS, TIMSS),
       then create a temp file with all prefixs of a cnt merged.
       but other asssessments only need to loop over prefix (such as LLECE).
       See the two examples below and change according to your needs */

	   // Temporary copies of the 3 rawdatasets needed for each country 
	
	local list SU_P1_EGRA_Analysis SU_P2_EGRA_Analysis SU_P3_EGRA_Analysis
	 foreach file in `list' {
         if `from_datalibweb'==1 {
           noi edukit_datalibweb, d(country(`region') year(`year') type(EDURAW) surveyid(`surveyid') filename(2018.dta) `shortcut')
         }
         else {
           use "`input_dir'/`file'.dta", clear
         }
		  capture confirm variable Readpct
		if (_rc == 0) {
		rename Readpct readpct3
}
		gen study = "`file'"
		rename *, lower
         compress
         save "`temp_dir'/`file'.dta", replace
	}

    noi disp as res "{phang}Step 1 completed (`output_file'){p_end}"


    *---------------------------------------------------------------------------
    * 2) Combine all rawdata into a single file (merge and append)
    *---------------------------------------------------------------------------

    /* NOTE: the merge / append of all rawdata saved in temp in above step
       will vary slightly by assessment.
       See the two examples continuedw and change according to your needs */
	   
	   local list SU_P1_EGRA_Analysis SU_P2_EGRA_Analysis
	    foreach file in `list' {
	   append using "`temp_dir'/`file'.dta", force
	  
	   }
	   
	   
	   *Just one file
    noi disp as res "{phang}Step 2 completed (`output_file'){p_end}"


    *---------------------------------------------------------------------------
    * 3) Standardize variable names across all assessments
    *---------------------------------------------------------------------------
    // For each variable class, we create a local with the variables in that class
    //     so that the final step of saving the GLAD dta  knows which vars to save

    // Every manipulation of variable must be enclosed by the ddi tags
    // Use clonevar instead of rename (preferable over generate)
    // The labels should be the same.
    // The generation of variables was commented out and should be replaced as needed

    // ID Vars:
    local idvars "idcntry_raw idregion year idschool idlearner"

    *<_idcntry_raw_>
    gen idcntry_raw = "`region'"
    label var idcntry_raw "Country ID, as coded in rawdata"
    *</_idcntry_raw_>
	
	*<_idregion_>
	/*This dataset doesnt have state variable, so used district instead */
    gen idregion = province
    label var idcntry_raw "Region"
    *</_idregion_>
	
	*<_year_>
	replace year = 2018 if year == .
	label var year "Year"
	tostring year, replace
	*</_year_>

   *<_idschool_> 
	clonevar idschool=fpc_school 
    label var idschool "School ID"
    *<_idschool_> */

    /*<_idclass_> - Information not available 
    label var idclass "Class ID"
    *</_idclass_>*/
	
    *<_idlearner_>
	gen idlearner = _n
    label var idlearner "Learner ID"
    *</_idlearner_>

    /* Drop any value labels of idvars, to be okay to append multiple surveys
    foreach var of local idvars {
      label values `var' .
    }*/


    // VALUE Vars: 	  /* CHANGE HERE FOR YOUR ASSESSMENT!!! PIRLS EXAMPLE */
    local valuevars	"score_egra* "

    *<_score_assessment_subject_pv_>
	clonevar score_egra_read = read_comp_score_pcnt
    label var score_egra_read "Percentage of correct reading comprehension questions for `assessment'"
    *}
    *</_score_assessment_subject_pv_>

    /*<_level_assessment_subject_pv_>
    *foreach pv in 01 02 03 04 05 {
      *clonevar level_pirls_read_`pv' = asribm`pv'
      label var level_pirls_read_`pv' "Plausible value `pv': `assessment' level for reading"
    *}
    *</_level_assessment_subject_pv_>*/


    // TRAIT Vars:
    local traitvars	"age male urban idgrade total"

	*<_total_> 
	gen total = 1 
	label define total 1 "total"
	label values total total
	*<_total_>
	
    *<_age_>
    *clonevar age = std_age	
    label var age "Learner age at time of assessment"
    *</_age_>

    *<_urban_> 
	encode status, gen(urban)
	drop status
	replace urban=0 if urban==1
	replace urban=1 if urban==2
	label define urban 1 "urban" 0 "rural", replace
	label val urban urban
    label var urban "School is located in urban/rural area"
    *</_urban_>*/

    /*<_urban_o_>
    *decode acbg05a, g(urban_o)
    label var urban_o "Original variable of urban: population size of the school area"
    *</_urban_o_>*/

    *<_male_>
    gen byte male = .
	replace male = 0 if gender==2
	replace male = 1 if gender==1
	label define male 1 "male" 0 "female", replace
	label val male male
	drop gender
    label var male "Learner gender is male/female"
    *</_male_>

    *<_idgrade_>
	gen idgrade = grade
    label var idgrade "Grade ID"
    *</_idgrade_>

    // SAMPLE Vars:		 	  /* CHANGE HERE FOR YOUR ASSESSMENT!!! PIRLS EXAMPLE */
    local samplevars "learner_weight national_level nationally_representative regionally_representative"
	
	*<_Nationally_representative_> 
	gen national_level = 1
	*</_Nationally_representative_>
	
		*<_Nationally_representative_> 
	gen nationally_representative = 1
	*</_Nationally_representative_>
	
	*<_Regionally_representative_> 
	gen regionally_representative = 0
	*<_Regionally_representative_>


    *<_learner_weight_>
	/*The sample has weights for school, and for boys and girls P1, P2, P3. Just the variable weight seems general but require to confirm this is the total weight*/
	
    gen learner_weight  = weight
    label var learner_weight "Total learner weight"
    *</_learner_weight_>
	
    /*<_psu_>
    *clonevar su1  = school_code
    label var su1 "Primary sampling unit"
    *</_psu_>
	
	*<_strata1_>
	*clonevar strata1  = treatment
    label var strata1 "Strata 1"
    *</_strata1_> 
	
	*<_fpc1_>
    label var fpc1 "fpc 1"
    *</_fpc1_>

	*<_su2_>
	*clonevar su2 = id
    label var su2 "Sampling unit 2"
    *</_su2_>
	
	*<_strata2_>
	*clonevar strata2 = strat2
    label var strata2 "Strata 2"
    *</_strata2_> 

	*<_fpc2_>
    label var fpc2 "fpc 2"
    *</_fpc2_>
	
	*<_su3_>
	*gen su3 = _n
    label var su3 "Sampling unit 3"
    *</_su3_>
	
	*<_strata3_>
	*clonevar strata2 = 
    label var strata3 "Strata 2"
    *</_strata3_> 

	*<_fpc3_>
    label var fpc3 "fpc 3"
    *</_fpc3_>
	
	*<_su4_>
	*gen su4 = _n
    label var su4 "Sampling unit 4"
    *</_su4_>
	
	*<_strata4_>
	*clonevar strata2 = 
    label var strata4 "Strata 4"
    *</_strata4_> 

	*<_fpc4_>
    label var fpc4 "fpc 4"
    *</_fpc4_>
	
	*<_su5_>
	*gen su5 = _n
    label var su5 "Sampling unit 5"
    *</_su5_>
	
	*<_strata5_>
	*clonevar strata2 = 
    label var strata4 "Strata 4"
    *</_strata5_> 

	*<_fpc5_>
    label var fpc5 "fpc 5"
    *</_fpc5_> */

    /*<_jkzone_>
    label var jkzone "Jackknife zone"
    *</_jkzone_>

    *<_jkrep_>
    label var jkrep "Jackknife replicate code"
    *</_jkrep_>*/ */
	svyset [pweight= learner_weight]
 

    noi disp as res "{phang}Step 3 completed (`output_file'){p_end}" 


    *---------------------------------------------------------------------------
    * 4) ESCS and other calculations
    *---------------------------------------------------------------------------

    // Placeholder for other operations that we may want to include (kept in ALL-BASE)
    *<_escs_>
	*ESCS variables avaialble
	*Develop code for ESCS
    * code for ESCS
    * label for ESCS
    *</_escs_>

    noi disp as res "{phang}Step 4 completed (`output_file'){p_end}"

    *---------------------------------------------------------------------------
    * 5) Bring WB countrycode & harmonization thresholds, and save dtas
    *---------------------------------------------------------------------------

    // Brings World Bank countrycode from ccc_list - No need to merge as country level data
	clonevar countrycode = idcntry_raw
    // NOTE: the *assert* is intentional, please do not remove it.
    // if you run into an assert error, edit the 011_rawdata/master_countrycode_list.csv
    *merge m:1 idcntry_raw using "`temp_dir'/countrycode_list.dta", keep(match) assert(match using) nogen

    // Surveyid is needed to merge harmonization proficiency thresholds
    gen str surveyid = "`region'_`year'_`assessment'"
    label var surveyid "Survey ID (Region_Year_Assessment)"

    // New variable class: keyvars (not IDs, but rather key to describe the dataset)
    local keyvars "surveyid countrycode national_level"

    /* Harmonization of proficiency on-the-fly, based on thresholds as CPI
    glad_hpro_as_cpi
    local thresholdvars "`r(thresholdvars)'"
    local resultvars    "`r(resultvars)'"*/

    // Update valuevars to include newly created harmonized vars (from the ado)
    local valuevars : list valuevars | resultvars
	
	*<_language_test_> 
	
/*It is not clear from the report the language of the test, but my take is Kinyarwanda from the reading. The variable language doesnt have labels. Worth double checking if the testing was in English or Kinyarwanda */
	gen language_test = "Kinyarwanda"
	*<_language_test_>

	
				// Additional metadata: EGRA characteristics
		char _dta[nationally_representative]    "1"
		char _dta[regionally_representative]    "0"


    // This function compresses the dataset, adds metadata passed in the arguments as chars, save GLAD_BASE.dta
    // which contains all variables, then keep only specified vars and saves GLAD.dta, and delete files in temp_dir
    edukit_save,  filename("`output_file'") path("`output_dir'") dir2delete("`temp_dir'")              ///
                idvars("`idvars'") varc("key `keyvars'; value `valuevars'; trait `traitvars'; sample `samplevars'") ///
                metadata("`metadata'") collection("GLAD")
				
*Results close but not exactly matching yet
 /* }

  else {
    noi disp as txt "Skipped creation of `output_file'.dta (already found in clone)"
    // Still loads it, to generate documentation
    use "`output_dir'/`output_file'.dta", clear
  }
}
