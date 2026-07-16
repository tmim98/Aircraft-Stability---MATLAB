%% RUN_PARAMETRIC_ANALYSIS
% User-facing entry point for the parametric-analysis workflow.
%
% Current implemented parameter:
%   u_0
%
% Purpose:
%   This script runs the existing combined aircraft-stability workflow first,
%   then performs the implemented u_0 parametric sweep, exports the sweep
%   workbook, and creates the sweep plots in a case-specific results folder.
%
% This script intentionally keeps the parametric logic outside App Designer.
% It calls the validated analysis path through:
%
%   run_combined_AVS_analysis_FINAL.m
%
% and then uses the PA-1/PA-2/PA-3 helper functions:
%
%   run_parametric_sweep.m
%   export_parametric_workbook.m
%   plot_parametric_results.m
%
% Outputs left in the MATLAB workspace:
%   param_out                    Parametric sweep output struct
%   parametric_results_folder     Folder for the current parametric run
%   parametric_workbook_file      Exported workbook path
%   parametric_plot_folder        Folder containing generated plot files
%   parametric_plot_files         Cell array of generated plot paths
%
% Notes:
%   - Aircraft selection is handled by run_combined_AVS_analysis_FINAL.m.
%   - This script does not modify aircraft input files.
%   - The current first workflow is fixed to parameter_name = 'u_0'.

fprintf('\n============================================================\n');
fprintf('PARAMETRIC ANALYSIS ENTRY SCRIPT\n');
fprintf('Current implemented parameter: u_0\n');
fprintf('============================================================\n\n');

% -------------------------------------------------------------------------
% Step 1: Run the existing combined workflow exactly as before.
% -------------------------------------------------------------------------
% This script creates long_pAV, lat_pAV, out, and related baseline outputs in
% the current workspace. It also lets the user select NAVION or B747 through
% the existing aircraft-case selector.
run_combined_AVS_analysis_FINAL;

% -------------------------------------------------------------------------
% Step 2: Validate that the required baseline inputs are available.
% -------------------------------------------------------------------------
if ~exist('long_pAV', 'var') || ~isstruct(long_pAV)
    error('run_parametric_analysis:MissingLongitudinalInput', ...
        ['The variable long_pAV was not found after running ', ...
         'run_combined_AVS_analysis_FINAL.m. Parametric analysis cannot continue.']);
end

if ~exist('lat_pAV', 'var') || ~isstruct(lat_pAV)
    error('run_parametric_analysis:MissingLateralInput', ...
        ['The variable lat_pAV was not found after running ', ...
         'run_combined_AVS_analysis_FINAL.m. Parametric analysis cannot continue.']);
end

% -------------------------------------------------------------------------
% Step 3: Resolve case/results metadata.
% -------------------------------------------------------------------------
parameter_name = 'u_0';

if exist('out', 'var') && isstruct(out)
    aircraft_case_tag = local_get_nested_text(out, {'meta','aircraft_case'}, 'AIRCRAFT');
    case_results_folder = local_get_nested_text(out, {'meta','results_folder'}, '');
else
    aircraft_case_tag = 'AIRCRAFT';
    case_results_folder = '';
end

if isempty(case_results_folder)
    script_folder = fileparts(mfilename('fullpath'));
    if isempty(script_folder)
        script_folder = pwd;
    end
    case_results_folder = fullfile(script_folder, 'results', aircraft_case_tag);
end

parametric_results_folder = fullfile(case_results_folder, 'Parametric', parameter_name);
parametric_plot_folder = fullfile(parametric_results_folder, 'plots');

if ~exist(parametric_results_folder, 'dir')
    mkdir(parametric_results_folder);
end
if ~exist(parametric_plot_folder, 'dir')
    mkdir(parametric_plot_folder);
end

fprintf('\nParametric results folder:\n  %s\n', parametric_results_folder);

% -------------------------------------------------------------------------
% Step 4: Run the implemented u_0 parametric sweep.
% -------------------------------------------------------------------------
fprintf('\nRunning parametric sweep for parameter: %s\n', parameter_name);

param_out = run_parametric_sweep(long_pAV, lat_pAV, parameter_name);

fprintf('\nParametric sweep summary:\n');
disp(param_out.summary_table);

% -------------------------------------------------------------------------
% Step 5: Export workbook and plots.
% -------------------------------------------------------------------------
parametric_workbook_file = fullfile(parametric_results_folder, ...
    [parameter_name '_parametric_summary.xlsx']);

parametric_workbook_file = export_parametric_workbook(param_out, parametric_workbook_file);
parametric_plot_files = plot_parametric_results(param_out, parametric_plot_folder);

fprintf('\nParametric workbook exported to:\n  %s\n', parametric_workbook_file);

fprintf('\nParametric plots exported to:\n');
for k = 1:numel(parametric_plot_files)
    fprintf('  %s\n', parametric_plot_files{k});
end

fprintf('\nPA-4 run_parametric_analysis.m completed successfully.\n');
fprintf('============================================================\n\n');

% -------------------------------------------------------------------------
% Local helper functions
% -------------------------------------------------------------------------
function value = local_get_nested_text(s, field_path, default_value)
    value = default_value;
    if nargin < 3
        default_value = '';
        value = default_value;
    end
    if ~isstruct(s)
        return;
    end

    current_value = s;
    for k = 1:numel(field_path)
        field_name = field_path{k};
        if isstruct(current_value) && isfield(current_value, field_name)
            current_value = current_value.(field_name);
        else
            return;
        end
    end

    if isstring(current_value) && isscalar(current_value)
        value = char(current_value);
    elseif ischar(current_value)
        value = current_value;
    elseif isnumeric(current_value) && isscalar(current_value)
        value = num2str(current_value);
    end
end
