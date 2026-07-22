# AIRCRAFT STABILITY ANALYSIS PROJECT

## IMPORTANT — HOW TO RUN THE MAIN STABILITY TOOL

To run the standard aircraft-stability analysis, run only this file:

```text
run_combined_AVS_analysis_FINAL.m
```

Open MATLAB, open this runner file, and press **Run**.

When the runner starts, a small aircraft-selection window appears. Choose the aircraft case you want to analyze, for example:

```text
NAVION
B747
```

After choosing the aircraft, the runner automatically performs:

1. Longitudinal stability analysis.
2. Lateral/directional stability analysis.
3. Mode-response plotting.
4. Combined text-report creation.
5. Optional Excel workbook export.

Do **not** run the longitudinal core or lateral/directional core directly for the full project.

Do **not** manually run the aircraft input files unless you are debugging a specific aircraft case.

The main MATLAB output variable created by `run_combined_AVS_analysis_FINAL.m` is:

```text
out
```

The main output folders are created automatically under:

```text
results\<AIRCRAFT_CASE>
```

For example:

```text
results\NAVION
results\B747
```

---

## IMPORTANT — HOW TO RUN PARAMETRIC ANALYSIS

The implemented parametric-analysis backend currently supports these one-dimensional sweep variables:

```text
u_0
x_cg / cg_mac
```

The user-facing entry script is:

```text
run_parametric_analysis.m
```

This script calls the standard combined runner:

```text
run_combined_AVS_analysis_FINAL.m
```

and then runs the default implemented parametric workflow. At this stage, the scripted entry workflow is still centered on the `u_0` sweep.

The shared parametric-analysis backend is:

```text
run_parametric_sweep.m
export_parametric_workbook.m
plot_parametric_results.m
```

To run the implemented `x_cg` sweep directly, run the standard combined runner first, select the aircraft case, and then call:

```matlab
param_out = run_parametric_sweep(long_pAV, lat_pAV, 'x_cg');

workbook_file = export_parametric_workbook( ...
    param_out, ...
    'x_cg_parametric_summary.xlsx');

plot_files = plot_parametric_results( ...
    param_out, ...
    'x_cg_plots');
```

Generated parametric-analysis outputs are normally saved under:

```text
results\<AIRCRAFT_CASE>\Parametric\<PARAMETER_NAME>\
```

For example:

```text
results\NAVION\Parametric\u_0\
results\B747\Parametric\u_0\
results\NAVION\Parametric\x_cg\
results\B747\Parametric\x_cg\
```

The `u_0` plot folder contains files such as:

```text
u_0_CL0_qbar.png
u_0_stability_envelope.png
u_0_longitudinal_eigenvalues.png
u_0_lateral_eigenvalues.png
u_0_A_long_sensitivity.png
u_0_A_lat_sensitivity.png
```

The `x_cg` plot folder contains files such as:

```text
x_cg_static_stability_envelope.png
x_cg_Cm_alpha_dCm_dCL.png
x_cg_stability_envelope.png
x_cg_longitudinal_eigenvalues.png
x_cg_A_long_sensitivity.png
```

Generated parametric-analysis results are output artifacts. They should not normally be committed to the repository unless example outputs are intentionally being versioned.

---

## CURRENT PARAMETRIC-ANALYSIS STATUS

The implemented parametric-analysis backend currently supports one-dimensional sweeps for:

```text
u_0
x_cg / cg_mac
```

### `u_0` policy

The `u_0` sweep uses the following policy:

1. Candidate speed values are generated around the baseline `u_0`.
2. A hard Mach cap is enforced:

```text
M <= 0.9
```

3. Values above the Mach cap are clipped or removed from the accepted sweep.
4. Dynamic pressure is recomputed at every accepted point:

```text
qbar = 0.5*rho*u_0^2
```

5. `CL0` is updated with baseline-preserving trim-consistent scaling:

```text
CL0_new = CL0_baseline * (qbar_baseline/qbar_new)
```

Equivalently, when `rho` and `S` are fixed:

```text
CL0_new = CL0_baseline * (u0_baseline/u0_new)^2
```

6. Lateral lift-coefficient aliases are synchronized, including `CL0` and `CL` where present.
7. Mach-derived speed derivatives are recomputed when source fields exist:

```text
C_Lu  = M*CL_M
C_Du  = M*CD_M
C_m_u = M*Cm_M
```

The `u_0` implementation has been checked on both NAVION and B747. At the baseline sweep point, the parametric runner reproduces the normal combined-runner eigenvalues exactly for both longitudinal and lateral/directional branches.

### `x_cg / cg_mac` policy

The `x_cg` sweep uses the normalized center-of-gravity position as the sweep variable:

```text
cg_mac = x_cg/c_bar
```

Default sweep range:

```text
baseline cg_mac ± 0.20
```

Safety limits:

```text
0.05 <= cg_mac <= 0.60
```

The `x_cg` sweep is currently a longitudinal-only parametric workflow. Lateral/reference `x_cg` aliases are synchronized for consistency, but the lateral/directional branch is not rerun by default.

The accepted `x_cg` policy preserves the baseline horizontal-tail reference station:

```text
x_tail_ref = x_cg_baseline + lt_baseline
lt_new     = x_tail_ref - x_cg_new
```

Then the horizontal-tail volume ratio is recomputed:

```text
V_H = lt*St/(S*c_bar)
```

Because the standard longitudinal core gives direct `Cm_alpha` input values priority when they exist, the parametric helper updates `Cm_alpha` with a baseline-preserving incremental relation. This makes the `x_cg` sweep affect both static and dynamic longitudinal behavior without discarding the validated baseline derivative.

Static stability is tracked by two methods:

```text
Primary method:   Cm_alpha / dCm_dCL
Secondary method: neutral-point static margin
```

If the two methods disagree, both are shown and the disagreement is flagged. The primary static-stability classification is not hidden.

The `x_cg` implementation estimates critical CG locations when a zero crossing exists inside the accepted sweep range.

---

## REQUIRED PROJECT FOLDER STRUCTURE

Keep the main project folder organized like this:

```text
Aircraft Stability\
    run_combined_AVS_analysis_FINAL.m
    run_parametric_analysis.m
    run_parametric_sweep.m
    apply_parametric_variation.m
    build_u0_sweep_values.m
    build_xcg_sweep_values.m
    export_parametric_workbook.m
    plot_parametric_results.m
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
            Parametric\
                u_0\
                    u_0_parametric_summary.xlsx
                    plots\
                x_cg\
                    x_cg_parametric_summary.xlsx
                    plots\

        B747\
            combined_stability_report.txt
            combined_stability_outputs.xlsx
            Mode_Response_Plots\
            Parametric\
                u_0\
                    u_0_parametric_summary.xlsx
                    plots\
                x_cg\
                    x_cg_parametric_summary.xlsx
                    plots\

    BackUp_Obsolete\
        optional old/duplicate/archived files
```

The exact name of the backup folder is not important. It is only for files that are not part of the active workflow.

---

## FILES YOU USUALLY NEED TO OPEN

For standard stability analysis, open only:

```text
run_combined_AVS_analysis_FINAL.m
```

For parametric analysis, open only:

```text
run_parametric_analysis.m
```

You do **not** need to open the analysis cores for normal use.

If you are editing aircraft data, open the two input files inside that aircraft's case folder:

```text
aircraft_cases\<AIRCRAFT_CASE>\AVSrun_analysis.m
aircraft_cases\<AIRCRAFT_CASE>\AVS_input_lateral_current.m
```

For example, for B747:

```text
aircraft_cases\B747\AVSrun_analysis.m
aircraft_cases\B747\AVS_input_lateral_current.m
```

---

## WHAT THE STANDARD RUNNER CREATES

For each selected aircraft, `run_combined_AVS_analysis_FINAL.m` creates or updates:

```text
results\<AIRCRAFT_CASE>\combined_stability_report.txt
results\<AIRCRAFT_CASE>\combined_stability_outputs.xlsx
results\<AIRCRAFT_CASE>\Mode_Response_Plots\
```

The combined report contains both:

```text
Longitudinal analysis report
Lateral/directional analysis report
```

The Excel workbook contains flattened grouped output sheets, including:

```text
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
```

For details on the SI/AVS input and output containers, workbook export sheets, and conversion scope, see:

```text
UNIT_SYSTEMS.md
```

The mode-response plot folder should contain the five main mode plots:

```text
Phugoid
Short-period
Roll mode
Spiral mode
Dutch roll
```

---

## WHAT THE PARAMETRIC RUNNER CREATES

For each selected aircraft, the parametric backend creates or updates parameter-specific output folders such as:

```text
results\<AIRCRAFT_CASE>\Parametric\u_0\u_0_parametric_summary.xlsx
results\<AIRCRAFT_CASE>\Parametric\u_0\plots\

results\<AIRCRAFT_CASE>\Parametric\x_cg\x_cg_parametric_summary.xlsx
results\<AIRCRAFT_CASE>\Parametric\x_cg\plots\
```

The parametric workbook contains sheets such as:

```text
Summary
Sweep_Definition
Baseline
Warnings
Failures
Longitudinal_Eigenvalues
A_Long_Entries
B_Long_Entries
Longitudinal_Nondim
Longitudinal_Dimensional
```

For `u_0`, the workbook and plots may also include lateral/directional eigenvalues and lateral/directional matrix entries because `u_0` affects both branches.

For `x_cg`, the workflow is currently longitudinal-only, so the useful plots are:

```text
static-stability envelope
Cm_alpha and dCm/dCL versus cg_mac
dynamic stability envelope
longitudinal eigenvalue movement in the complex plane
longitudinal A-matrix sensitivity heatmap
```

In the A-matrix sensitivity heatmaps, the displayed numbers are maximum absolute percent changes from the baseline matrix entry over the sweep. `NaN` means the percent change is undefined, usually because the baseline matrix entry is zero.

---

## WHAT THE MAIN OUTPUT STRUCT CONTAINS

After `run_combined_AVS_analysis_FINAL.m` finishes, inspect:

```text
out
```

Important standardized fields:

```text
out.inputs_AVS
out.inputs_SI
out.longitudinal_outputs_SI
out.longitudinal_outputs_AVS
out.lateral_outputs_AVS
out.lateral_outputs_SI
out.summary
out.reports
out.saved_files
```

Legacy compatibility fields are also retained:

```text
out.inputs
out.longitudinal
out.lateral_directional
```

The individual outputs are also kept in the MATLAB workspace:

```text
long_out
lat_out
```

The combined report text is stored in:

```text
combined_report_text
```

The saved report path is stored in:

```text
combined_report_file
```

If the Excel export is created, its path is stored in:

```text
combined_xlsx_file
```

After `run_parametric_analysis.m` or a direct `run_parametric_sweep.m` call finishes, the parametric output structure is stored as:

```text
param_out
```

---

## HOW AIRCRAFT CASES WORK

Each aircraft case has its own folder inside:

```text
aircraft_cases
```

Each case folder must contain exactly these two aircraft-specific files:

```text
AVSrun_analysis.m
AVS_input_lateral_current.m
```

The shared analysis files stay in the main project folder:

```text
AVS_to_SI.m
SI_longitudinal_analysis_grouped.m
AVS_lateral_directional_analysis.m
plot_stability_mode_responses.m
```

This means that the aircraft data changes from case to case, but the analysis method remains shared.

---

## ADDING A NEW AIRCRAFT CASE

To add a new aircraft:

1. Create a new folder under `aircraft_cases`.

   Example:

```text
aircraft_cases\C172
```

2. Copy an existing aircraft case folder as a starting point.

3. Edit the two copied input files:

```text
AVSrun_analysis.m
AVS_input_lateral_current.m
```

4. Update the aircraft geometry, mass, inertia, aerodynamic derivatives, control derivatives, and flight condition.

5. Run:

```text
run_combined_AVS_analysis_FINAL.m
```

6. Select the new aircraft in the popup menu.

The runner automatically detects aircraft cases whose folders contain both required input files.

---

## NOTES ABOUT INPUTS AND UNITS

The project uses AVS / aviation-style user inputs where appropriate.

Typical units:

```text
Length: ft
Area: ft^2
Speed: knots in the AVS input files
Weight: lbf
Inertia: slug*ft^2
Density: slug/ft^3
Angles: radians unless the input-file comment explicitly says degrees
```

The longitudinal AVS input file is converted to SI internally using:

```text
AVS_to_SI.m
```

The lateral/directional core works directly with AVS-consistent quantities.

---

## NOTES ABOUT UNIT SYSTEMS

For details on the SI/AVS input and output containers, workbook export sheets, and conversion scope, see:

```text
UNIT_SYSTEMS.md
```

For the batch-based validation procedure used during development, see:

```text
VALIDATION_WORKFLOW.md
```

For parametric-analysis variable policy, see:

```text
PARAMETRIC_PARAMETER_MAP.md
```

---

## NOTES ABOUT THE ANALYSIS FILES

The longitudinal core is:

```text
SI_longitudinal_analysis_grouped.m
```

The lateral/directional core is:

```text
AVS_lateral_directional_analysis.m
```

The mode-response plotting file is:

```text
plot_stability_mode_responses.m
```

The parametric plotting file is:

```text
plot_parametric_results.m
```

The combined runner calls the standard cores automatically.

The parametric runner calls the combined runner first and then calls the parametric backend.

Do not edit the cores unless you are intentionally changing the analysis method. For ordinary aircraft changes, edit only the aircraft-case input files.

---

## BACKUP / OBSOLETE FILES

Old files, duplicate files, test files, and autosave files may be moved to:

```text
BackUp_Obsolete
```

or another clearly named archive folder.

Examples of files that can usually be archived:

```text
old runner versions
duplicate input files
temporary test scripts
MATLAB autosave files with the .asv extension
diagnostic workbooks used for local validation
```

Do not leave obsolete files with confusing names in the active project folder if they are no longer part of the workflow.

The active project should contain only the current runners, shared cores, plotting files, conversion files, parametric-analysis files, digitized-figure data, aircraft-case folders, documentation files, and results folder.

---

## QUICK CHECKLIST BEFORE RUNNING STANDARD ANALYSIS

Before pressing Run, check:

1. The main project folder contains the shared MATLAB files.
2. The aircraft case you want has its own folder under `aircraft_cases`.
3. That aircraft folder contains:

```text
AVSrun_analysis.m
AVS_input_lateral_current.m
```

4. The `Digitalized Figs` folder is present if the selected case needs digitized figure CSV files.
5. You are running:

```text
run_combined_AVS_analysis_FINAL.m
```

After running, check:

1. The correct aircraft was selected in the popup.
2. The report was saved in `results\<AIRCRAFT_CASE>`.
3. The plot folder contains the five mode-response plots.
4. If needed, answer `Y` to create the Excel workbook.

---

## QUICK CHECKLIST BEFORE RUNNING PARAMETRIC ANALYSIS

Before running parametric analysis, check:

1. You are on the intended development branch if editing code.
2. The implemented parametric variables are:

```text
u_0
x_cg / cg_mac
```

3. For the default user-facing parametric workflow, run:

```text
run_parametric_analysis.m
```

4. For a direct `x_cg` backend test, run the combined runner first and then call:

```matlab
param_out = run_parametric_sweep(long_pAV, lat_pAV, 'x_cg');
```

After running, check:

1. The correct aircraft was selected in the popup from `run_combined_AVS_analysis_FINAL.m`.
2. The parametric workbook was saved under the correct parameter folder, for example:

```text
results\<AIRCRAFT_CASE>\Parametric\u_0\
results\<AIRCRAFT_CASE>\Parametric\x_cg\
```

3. The plot folder exists under the selected parameter folder.
4. The stability-envelope plot, eigenvalue plots, and A-matrix sensitivity plots were generated.
5. For `x_cg`, verify that static-stability output includes the primary `Cm_alpha / dCm_dCL` method, the secondary neutral-point method, and any method-disagreement warnings.
6. Generated workbooks and plot folders are not committed unless example outputs are intentionally being versioned.
