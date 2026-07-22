%% RUN_PARAMETRIC_ANALYSIS
% User-facing entry point for the parametric-analysis workflow.
%
% Purpose:
%   This script runs the existing combined aircraft-stability workflow first,
%   then lets the user choose one or more implemented parametric variables,
%   runs each selected one-dimensional sweep, exports the corresponding
%   workbook, and creates the corresponding plots in case-specific results
%   folders.
%
% Current implemented parameters are defined in:
%
%   get_parametric_parameter_catalog.m
%
% The script is intentionally catalog-driven so that future variables can be
% added to the catalog and then appear automatically in the user-facing
% selector. This is also intended to stay compatible with a future
% App Designer front-end, where the same catalog can populate a listbox or
% dropdown.
%
% This script intentionally keeps the parametric logic outside App Designer.
% It calls the validated analysis path through:
%
%   run_combined_AVS_analysis_FINAL.m
%
% and then uses the parametric backend/export/plot functions:
%
%   run_parametric_sweep.m
%   export_parametric_workbook.m
%   plot_parametric_results.m
%
% Outputs left in the MATLAB workspace:
%   selected_parametric_parameters   Struct array of selected catalog entries
%   parametric_runs                  Struct array of run/export/plot results
%   param_out                        Last completed parametric output struct
%
% Notes:
%   - Aircraft selection is handled by run_combined_AVS_analysis_FINAL.m.
%   - This script does not modify aircraft input files.
%   - Selecting multiple parameters currently runs multiple independent
%     one-dimensional sweeps from the same baseline aircraft case.
%   - Coupled multi-variable sweeps are intentionally not implemented here.

fprintf('\n============================================================\n');
fprintf('PARAMETRIC ANALYSIS ENTRY SCRIPT\n');
fprintf('Catalog-driven parameter selection\n');
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
% Step 3: Resolve aircraft/results metadata.
% -------------------------------------------------------------------------
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

% -------------------------------------------------------------------------
% Step 4: Load implemented parametric-variable catalog and let user select.
% -------------------------------------------------------------------------
parameter_catalog = get_parametric_parameter_catalog();
implemented_mask = [parameter_catalog.implemented];
implemented_catalog = parameter_catalog(implemented_mask);

if isempty(implemented_catalog)
    error('run_parametric_analysis:NoImplementedParameters', ...
        'No implemented parametric parameters were found in get_parametric_parameter_catalog.m.');
end

selected_indices = local_select_parametric_parameters(implemented_catalog);

if isempty(selected_indices)
    fprintf('\nNo parametric variable was selected. Parametric analysis cancelled.\n');
    fprintf('============================================================\n\n');
    return;
end

selected_parametric_parameters = implemented_catalog(selected_indices);

fprintf('\nSelected parametric variable(s):\n');
for k = 1:numel(selected_parametric_parameters)
    fprintf('  %d. %s\n', k, selected_parametric_parameters(k).display_name);
end

% -------------------------------------------------------------------------
% Step 5: Run each selected one-dimensional sweep from the same baseline.
% -------------------------------------------------------------------------
parametric_runs = repmat(local_empty_parametric_run(), numel(selected_parametric_parameters), 1);

for k = 1:numel(selected_parametric_parameters)
    entry = selected_parametric_parameters(k);

    fprintf('\n------------------------------------------------------------\n');
    fprintf('Running parametric sweep %d of %d\n', k, numel(selected_parametric_parameters));
    fprintf('Parameter: %s\n', entry.display_name);
    fprintf('Backend key: %s\n', entry.parameter_name);
    fprintf('------------------------------------------------------------\n');

    parametric_results_folder = fullfile(case_results_folder, 'Parametric', entry.folder_name);
    parametric_plot_folder = fullfile(parametric_results_folder, 'plots');

    if ~exist(parametric_results_folder, 'dir')
        mkdir(parametric_results_folder);
    end
    if ~exist(parametric_plot_folder, 'dir')
        mkdir(parametric_plot_folder);
    end

    parametric_workbook_file = fullfile(parametric_results_folder, entry.workbook_file_name);

    parametric_runs(k).parameter_name = entry.parameter_name;
    parametric_runs(k).display_name = entry.display_name;
    parametric_runs(k).results_folder = parametric_results_folder;
    parametric_runs(k).plot_folder = parametric_plot_folder;
    parametric_runs(k).workbook_file = parametric_workbook_file;

    try
        param_out = run_parametric_sweep(long_pAV, lat_pAV, entry.parameter_name);

        fprintf('\nParametric sweep summary for %s:\n', entry.display_name);
        disp(param_out.summary_table);

        parametric_workbook_file = export_parametric_workbook(param_out, parametric_workbook_file);
        parametric_plot_files = plot_parametric_results(param_out, parametric_plot_folder);

        parametric_runs(k).param_out = param_out;
        parametric_runs(k).workbook_file = parametric_workbook_file;
        parametric_runs(k).plot_files = parametric_plot_files;
        parametric_runs(k).status = 'ok';

        fprintf('\nParametric workbook exported to:\n  %s\n', parametric_workbook_file);

        fprintf('\nParametric plots exported to:\n');
        for j = 1:numel(parametric_plot_files)
            fprintf('  %s\n', parametric_plot_files{j});
        end

    catch ME
        parametric_runs(k).status = 'failed';
        parametric_runs(k).error_identifier = ME.identifier;
        parametric_runs(k).error_message = ME.message;

        warning('run_parametric_analysis:ParameterRunFailed', ...
            'Parametric run failed for %s: %s', entry.parameter_name, ME.message);
    end
end

% -------------------------------------------------------------------------
% Step 6: Print final status summary.
% -------------------------------------------------------------------------
fprintf('\n============================================================\n');
fprintf('PARAMETRIC ANALYSIS RUN SUMMARY\n');
fprintf('Aircraft case: %s\n', aircraft_case_tag);
fprintf('Case results folder:\n  %s\n', case_results_folder);

for k = 1:numel(parametric_runs)
    fprintf('\n%d. %s\n', k, parametric_runs(k).display_name);
    fprintf('   Status: %s\n', parametric_runs(k).status);
    fprintf('   Results folder:\n     %s\n', parametric_runs(k).results_folder);
    if strcmp(parametric_runs(k).status, 'ok')
        fprintf('   Workbook:\n     %s\n', parametric_runs(k).workbook_file);
        fprintf('   Plot count: %d\n', numel(parametric_runs(k).plot_files));
    else
        fprintf('   Error: %s\n', parametric_runs(k).error_message);
    end
end

fprintf('\nPA-8 run_parametric_analysis.m completed.\n');
fprintf('============================================================\n\n');

% -------------------------------------------------------------------------
% Local helper functions
% -------------------------------------------------------------------------
function selected_indices = local_select_parametric_parameters(catalog)
    labels = local_catalog_labels(catalog);

    selected_indices = [];

    use_dialog = usejava('desktop') && feature('ShowFigureWindows');

    if use_dialog
        [idx, ok] = listdlg( ...
            'PromptString', {'Select parametric variable(s) to sweep:', ...
                             'Multiple selections are allowed.'}, ...
            'SelectionMode', 'multiple', ...
            'ListString', labels, ...
            'ListSize', [420 180], ...
            'Name', 'Parametric Variable Selection');

        if ok
            selected_indices = idx(:).';
        end
    else
        fprintf('\nAvailable implemented parametric variables:\n');
        for k = 1:numel(labels)
            fprintf('  %d. %s\n', k, labels{k});
        end
        raw_selection = input('Enter number(s), e.g. 1 or [1 2], then press Enter: ', 's');
        selected_indices = local_parse_index_selection(raw_selection, numel(labels));
    end
end

function labels = local_catalog_labels(catalog)
    labels = cell(1, numel(catalog));
    for k = 1:numel(catalog)
        labels{k} = sprintf('%s  --  %s', catalog(k).display_name, catalog(k).short_description);
    end
end

function idx = local_parse_index_selection(raw_selection, max_index)
    idx = [];
    if isempty(strtrim(raw_selection))
        return;
    end

    cleaned = regexprep(raw_selection, '[,\s;]+', ' ');
    cleaned = strrep(cleaned, '[', '');
    cleaned = strrep(cleaned, ']', '');
    values = sscanf(cleaned, '%f').';

    values = values(isfinite(values));
    values = round(values);
    values = unique(values(values >= 1 & values <= max_index), 'stable');

    idx = values;
end

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

function run_info = local_empty_parametric_run()
    run_info = struct();
    run_info.parameter_name = '';
    run_info.display_name = '';
    run_info.results_folder = '';
    run_info.plot_folder = '';
    run_info.workbook_file = '';
    run_info.plot_files = {};
    run_info.param_out = struct();
    run_info.status = 'not_run';
    run_info.error_identifier = '';
    run_info.error_message = '';
end
