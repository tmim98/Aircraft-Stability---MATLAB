# AIRCRAFT STABILITY ANALYSIS PROJECT

## IMPORTANT — HOW TO RUN THE TOOL

TO RUN THE PROJECT, ONLY RUN THIS FILE:

    run_combined_AVS_analysis_FINAL.m

Open MATLAB, open this runner file, and press Run.

When the runner starts, a small aircraft-selection window appears.
Choose the aircraft case you want to analyze, for example:

    NAVION
    B747

After choosing the aircraft, the runner automatically performs:

    1. Longitudinal stability analysis
    2. Lateral/directional stability analysis
    3. Mode-response plotting
    4. Combined text-report creation
    5. Optional Excel workbook export

DO NOT run the longitudinal core or lateral/directional core directly for the full project.

DO NOT manually run the aircraft input files unless you are debugging a specific aircraft case.

The main MATLAB output variable created by the runner is:

    out

The main output folders are created automatically under:

    results\<AIRCRAFT_CASE>

For example:

    results\NAVION
    results\B747


## REQUIRED PROJECT FOLDER STRUCTURE

Keep the main project folder organized like this:

    Aircraft Stability\
        run_combined_AVS_analysis_FINAL.m
        AVS_to_SI.m
        SI_longitudinal_analysis_grouped.m
        AVS_lateral_directional_analysis.m
        plot_stability_mode_responses.m

        Digitalized Figs\
            required digitized-figure CSV files

        aircraft_cases\
            NAVION\
                AVSrun_analysis.m
                AVS_input_lateral_current.m

            B747\
                AVSrun_analysis.m
                AVS_input_lateral_current.m

        results\
            NAVION\
                combined_stability_report.txt
                combined_stability_outputs.xlsx
                Mode_Response_Plots\

            B747\
                combined_stability_report.txt
                combined_stability_outputs.xlsx
                Mode_Response_Plots\

        BackUp_Obsolete\
            optional old/duplicate/archived files

The exact name of the backup folder is not important. It is only for files that are not part of the active workflow.


## FILES YOU USUALLY NEED TO OPEN

For normal use, open only:

    run_combined_AVS_analysis_FINAL.m

You do NOT need to open the analysis cores.

If you are editing aircraft data, open the two input files inside that aircraft's case folder:

    aircraft_cases\<AIRCRAFT_CASE>\AVSrun_analysis.m
    aircraft_cases\<AIRCRAFT_CASE>\AVS_input_lateral_current.m

For example, for B747:

    aircraft_cases\B747\AVSrun_analysis.m
    aircraft_cases\B747\AVS_input_lateral_current.m


## WHAT THE RUNNER CREATES

For each selected aircraft, the runner creates or updates:

    results\<AIRCRAFT_CASE>\combined_stability_report.txt
    results\<AIRCRAFT_CASE>\combined_stability_outputs.xlsx
    results\<AIRCRAFT_CASE>\Mode_Response_Plots\

The combined report contains both:

    Longitudinal analysis report
    Lateral/directional analysis report

The Excel workbook contains flattened grouped output sheets, including:

    Summary
    Unit_System_Guide
    Longitudinal_Output
    Lateral_Directional_Output
    Longitudinal_Output_SI
    Longitudinal_Output_AVS
    Lateral_Output_AVS
    Lateral_Output_SI
    Longitudinal_Input_AVS
    Longitudinal_Input_SI
    Lateral_Directional_Input_AVS
    Inputs_AVS
    Inputs_SI
    Reports

For details on the SI/AVS input and output containers, workbook export sheets, and conversion scope, see:

    UNIT_SYSTEMS.md

The mode-response plot folder should contain the five main mode plots:

    Phugoid
    Short-period
    Roll mode
    Spiral mode
    Dutch roll


## WHAT THE MAIN OUTPUT STRUCT CONTAINS

After the runner finishes, inspect:

    out

Important standardized fields:

    out.inputs_AVS
    out.inputs_SI
    out.longitudinal_outputs_SI
    out.longitudinal_outputs_AVS
    out.lateral_outputs_AVS
    out.lateral_outputs_SI
    out.summary
    out.reports
    out.saved_files

Legacy compatibility fields are also retained:

    out.inputs
    out.longitudinal
    out.lateral_directional

The individual outputs are also kept in the MATLAB workspace:

    long_out
    lat_out

The combined report text is stored in:

    combined_report_text

The saved report path is stored in:

    combined_report_file

If the Excel export is created, its path is stored in:

    combined_xlsx_file


## HOW AIRCRAFT CASES WORK

Each aircraft case has its own folder inside:

    aircraft_cases

Each case folder must contain exactly these two aircraft-specific files:

    AVSrun_analysis.m
    AVS_input_lateral_current.m

The shared analysis files stay in the main project folder:

    AVS_to_SI.m
    SI_longitudinal_analysis_grouped.m
    AVS_lateral_directional_analysis.m
    plot_stability_mode_responses.m

This means that the aircraft data changes from case to case, but the analysis method remains shared.


## ADDING A NEW AIRCRAFT CASE

To add a new aircraft:

    1. Create a new folder under aircraft_cases.
       Example:

           aircraft_cases\C172

    2. Copy an existing aircraft case folder as a starting point.

    3. Edit the two copied input files:

           AVSrun_analysis.m
           AVS_input_lateral_current.m

    4. Update the aircraft geometry, mass, inertia, aerodynamic derivatives,
       control derivatives, and flight condition.

    5. Run:

           run_combined_AVS_analysis_FINAL.m

    6. Select the new aircraft in the popup menu.

The runner automatically detects aircraft cases whose folders contain both required input files.


## NOTES ABOUT INPUTS AND UNITS

The project uses AVS / aviation-style user inputs where appropriate.

Typical units:

    Length: ft
    Area: ft^2
    Speed: knots in the AVS input files
    Weight: lbf
    Inertia: slug*ft^2
    Density: slug/ft^3
    Angles: radians unless the input-file comment explicitly says degrees

The longitudinal AVS input file is converted to SI internally using:

    AVS_to_SI.m

The lateral/directional core works directly with AVS-consistent quantities.


## NOTES ABOUT UNIT SYSTEMS

For details on the SI/AVS input and output containers, workbook export sheets, and conversion scope, see:

    UNIT_SYSTEMS.md

For the batch-based validation procedure used during development, see:

    VALIDATION_WORKFLOW.md


## NOTES ABOUT THE ANALYSIS FILES

The longitudinal core is:

    SI_longitudinal_analysis_grouped.m

The lateral/directional core is:

    AVS_lateral_directional_analysis.m

The plotting file is:

    plot_stability_mode_responses.m

The combined runner calls these automatically.

Do not edit the cores unless you are intentionally changing the analysis method.
For ordinary aircraft changes, edit only the aircraft-case input files.


## BACKUP / OBSOLETE FILES

Old files, duplicate files, test files, and autosave files may be moved to:

    BackUp_Obsolete

or another clearly named archive folder.

Examples of files that can usually be archived:

    old runner versions
    duplicate input files
    temporary test scripts
    MATLAB autosave files with the .asv extension

Do not leave obsolete files with confusing names in the active project folder if they are no longer part of the workflow.

The active project should contain only the current runner, shared cores, plotting file, conversion file, digitized-figure data, aircraft_cases folder, and results folder.


## QUICK CHECKLIST BEFORE RUNNING

Before pressing Run, check:

    1. The main project folder contains the shared MATLAB files.
    2. The aircraft case you want has its own folder under aircraft_cases.
    3. That aircraft folder contains:
           AVSrun_analysis.m
           AVS_input_lateral_current.m
    4. The Digitalized Figs folder is present if the selected case needs digitized figure CSV files.
    5. You are running:
           run_combined_AVS_analysis_FINAL.m

After running, check:

    1. The correct aircraft was selected in the popup.
    2. The report was saved in results\<AIRCRAFT_CASE>.
    3. The plot folder contains the five mode-response plots.
    4. If needed, answer Y to create the Excel workbook.
