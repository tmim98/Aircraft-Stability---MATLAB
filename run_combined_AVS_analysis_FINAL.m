%% RUN_COMBINED_AVS_ANALYSIS
% Unified AVS-input driver for the complete stability analysis workflow.
%
% This script intentionally does NOT redefine aircraft inputs.
% It calls the existing AVS-based input/runner files:
%
%   1) AVSrun_analysis.m
%      - defines longitudinal AVS inputs
%      - converts AVS to SI using AVS_to_SI.m
%      - calls SI_longitudinal_analysis_grouped.m
%
%   2) AVS_input_lateral_current.m
%      - defines lateral/directional AVS inputs for the current aircraft
%      - calls AVS_lateral_directional_analysis.m
%
% The printed output from both analyses is captured and re-printed as one
% combined report. The numerical outputs are collected into one grouped
% struct named `out`.
%
% Optional workbook export:
%   After both analyses finish, the script asks whether to export the
%   combined results to one XLSX workbook. The export uses a conservative
%   flattened layout so scalars, vectors, matrices, complex eigenvalues,
%   nested structs, and text are all written safely.
%
% Public workspace outputs:
%   out                         Combined grouped output struct
%   long_out                    Longitudinal output struct
%   lat_out                     Lateral/directional output struct
%   combined_report_text         Combined text report as a string/char array
%   combined_report_file         Path to the saved .txt report
%   combined_xlsx_file           Path to the saved .xlsx workbook, if exported

clear; clc;

script_folder = fileparts(mfilename('fullpath'));
if isempty(script_folder)
    script_folder = pwd;
end
addpath(script_folder);

% -------------------------------------------------------------------------
% Aircraft case selection (popup selector)
% -------------------------------------------------------------------------
% The runner scans valid aircraft case folders and asks the user to choose.
% A valid case folder contains both:
%   AVSrun_analysis.m
%   AVS_input_lateral_current.m
%
% NAVION can still use legacy root-level inputs if no case folder exists.
% If the selector is cancelled, the run stops to avoid analyzing the wrong case.
aircraft_case = local_select_aircraft_case(script_folder);
%
% The XLSX export question remains separate later in this script.
% -------------------------------------------------------------------------

case_folder = local_resolve_aircraft_case(script_folder, aircraft_case);
results_folder = local_prepare_results_folder(script_folder, aircraft_case);

fprintf('\nSelected aircraft case: %s\n', local_case_tag(aircraft_case));
fprintf('Input folder:\n  %s\n', case_folder);
fprintf('Results folder:\n  %s\n', results_folder);

% -------------------------------------------------------------------------
% Run the two existing AVS workflows in isolated helper workspaces
% -------------------------------------------------------------------------
[long_out, long_pAV, long_pSI, longitudinal_report] = local_run_longitudinal(case_folder, script_folder);
[lat_out, lat_pAV, lateral_report] = local_run_lateral(case_folder, script_folder);

% -------------------------------------------------------------------------
% Build common grouped output struct
% -------------------------------------------------------------------------
out = struct();

out.meta = struct();
out.meta.file = mfilename;
out.meta.aircraft_case = local_case_tag(aircraft_case);
out.meta.project_folder = script_folder;
out.meta.case_folder = case_folder;
out.meta.results_folder = results_folder;
out.meta.aircraft = local_first_existing({ ...
    local_getfield_safe(lat_pAV, 'aircraft'), ...
    local_getfield_safe(long_pAV, 'aircraft'), ...
    'Aircraft stability analysis'});
out.meta.units_input = 'AVS';
out.meta.longitudinal_core = 'SI_longitudinal_analysis_grouped';
out.meta.lateral_directional_core = 'AVS_lateral_directional_analysis';
out.meta.created = char(datetime('now'));
out.meta.notes = ['Unified wrapper output. Aircraft-specific input scripts ', ...
                  'are called from the resolved case folder; shared analysis ', ...
                  'cores remain in the project root. Reports, spreadsheets, ', ...
                  'and plots are saved under results/<aircraft_case>.'];

out.inputs = struct();
out.inputs.longitudinal_AVS = long_pAV;
out.inputs.longitudinal_SI = long_pSI;
out.inputs.lateral_directional_AVS = lat_pAV;

% Standardized dual-unit input containers.
% These new fields are added for the SI/AVS expansion while the old
% out.inputs.* fields remain available for compatibility.
[out.inputs_SI, out.inputs_AVS] = build_dual_input_snapshots(long_pAV, long_pSI, lat_pAV);


out.longitudinal = long_out;
out.lateral_directional = lat_out;

out.reports = struct();
out.reports.longitudinal = longitudinal_report;
out.reports.lateral_directional = lateral_report;

% Compact summary for quick inspection at the command line.
out.summary = struct();
out.summary.longitudinal_eigenvalues = local_getfield_safe(long_out, 'eigA');
if isfield(long_out, 'modes_exact') && isfield(long_out.modes_exact, 'eigenvalues')
    out.summary.longitudinal_eigenvalues = long_out.modes_exact.eigenvalues;
end

out.summary.lateral_directional_eigenvalues = [];
if isfield(lat_out, 'modes_exact') && isfield(lat_out.modes_exact, 'eigenvalues')
    out.summary.lateral_directional_eigenvalues = lat_out.modes_exact.eigenvalues;
elseif isfield(lat_out, 'state_space') && isfield(lat_out.state_space, 'eigenvalues')
    out.summary.lateral_directional_eigenvalues = lat_out.state_space.eigenvalues;
end

if isfield(long_out, 'static_stability')
    out.summary.longitudinal_static_stability = long_out.static_stability;
end
if isfield(lat_out, 'static_stability')
    out.summary.lateral_directional_static_stability = lat_out.static_stability;
end

% -------------------------------------------------------------------------
% Combined text report
% -------------------------------------------------------------------------
combined_report_text = sprintf([ ...
    '============================================================\n', ...
    'COMBINED STABILITY ANALYSIS REPORT\n', ...
    '============================================================\n', ...
    'Generated by: %s.m\n', ...
    'Aircraft case: %s\n', ...
    'Aircraft label: %s\n', ...
    'Input case folder: %s\n', ...
    'Results folder: %s\n', ...
    'Input system: AVS aircraft-case input scripts\n', ...
    'Longitudinal core: %s\n', ...
    'Lateral/directional core: %s\n', ...
    'Generated on: %s\n\n', ...
    '============================================================\n', ...
    'LONGITUDINAL ANALYSIS REPORT\n', ...
    '============================================================\n\n', ...
    '%s\n\n', ...
    '============================================================\n', ...
    'LATERAL / DIRECTIONAL ANALYSIS REPORT\n', ...
    '============================================================\n\n', ...
    '%s\n'], ...
    out.meta.file, ...
    out.meta.aircraft_case, ...
    local_value_to_text(out.meta.aircraft), ...
    out.meta.case_folder, ...
    out.meta.results_folder, ...
    out.meta.longitudinal_core, ...
    out.meta.lateral_directional_core, ...
    out.meta.created, ...
    longitudinal_report, ...
    lateral_report);

out.reports.combined = combined_report_text;

combined_report_file = fullfile(results_folder, 'combined_stability_report.txt');
out.saved_files.combined_report = combined_report_file;
fid = fopen(combined_report_file, 'w');
if fid < 0
    warning('Could not open combined report file for writing: %s', combined_report_file);
else
    cleaner = onCleanup(@() fclose(fid));
    fprintf(fid, '%s', combined_report_text);
    clear cleaner;
end

% Print the combined report to the command window.
fprintf('%s\n', combined_report_text);

fprintf('\nCombined grouped output is available as variable: out\n');
fprintf('Longitudinal output is also available as: long_out\n');
fprintf('Lateral/directional output is also available as: lat_out\n');
fprintf('Combined report saved to:\n  %s\n', combined_report_file);
fprintf('\nUseful fields to inspect:\n');
fprintf('  out.longitudinal\n');
fprintf('  out.lateral_directional\n');
fprintf('  out.inputs\n');
fprintf('  out.inputs_SI\n');
fprintf('  out.inputs_AVS\n');
fprintf('  out.summary\n');
fprintf('  out.reports.combined\n');
% -------------------------------------------------------------------------
% Mode-response plots
% -------------------------------------------------------------------------
try
    plot_folder = fullfile(results_folder, 'Mode_Response_Plots');
    out.saved_files.mode_response_plots = plot_folder;
    plot_stability_mode_responses(out, plot_folder);
    fprintf('\nMode-response plots saved to:\n  %s\n', plot_folder);
catch ME
    warning('run_combined_AVS_analysis_FINAL:ModePlotsNotCreated', ...
    'Mode-response plots were not created: %s', ME.message);
end

% -------------------------------------------------------------------------
% Optional XLSX export
% -------------------------------------------------------------------------
combined_xlsx_file = '';
% This is the only interactive question in the combined runner.
export_answer = input('\nExport combined outputs to one XLSX workbook? Y/N [N]: ', 's');
if strcmpi(strtrim(export_answer), 'Y') || strcmpi(strtrim(export_answer), 'YES')
    combined_xlsx_file = fullfile(results_folder, 'combined_stability_outputs.xlsx');
    out.saved_files.combined_xlsx = combined_xlsx_file;
    local_export_combined_xlsx(out, combined_xlsx_file);
    fprintf('\nCombined XLSX workbook saved to:\n  %s\n', combined_xlsx_file);
    fprintf('Workbook sheets created:\n');
    fprintf('  Summary\n');
    fprintf('  Longitudinal_Output\n');
    fprintf('  Lateral_Directional_Output\n');
    fprintf('  Longitudinal_Input_AVS\n');
    fprintf('  Longitudinal_Input_SI\n');
    fprintf('  Lateral_Directional_Input_AVS\n');
    fprintf('  Inputs_AVS\n');
    fprintf('  Inputs_SI\n');
    fprintf('  Reports\n');
else
    fprintf('\nXLSX export skipped. You can re-run this script and answer Y later.\n');
end

%% ========================================================================
% Local helper functions
% ========================================================================
function aircraft_case = local_select_aircraft_case(project_folder)
    available_cases = local_available_aircraft_cases(project_folder);

    if isempty(available_cases)
        error('run_combined_AVS_analysis_FINAL:NoAircraftCases', ...
            ['No valid aircraft cases were found. Expected either root-level ', ...
             'NAVION input files or folders under aircraft_cases/<CASE_NAME>.']);
    end

    default_case = 'NAVION';
    default_index = find(strcmpi(available_cases, default_case), 1);
    if isempty(default_index)
        default_index = 1;
    end

    use_gui_selector = true;

    if use_gui_selector && exist('listdlg', 'file') == 2
        try
            [selected_index, ok_clicked] = listdlg( ...
                'Name', 'Aircraft Case Selection', ...
                'PromptString', {'Select aircraft case to analyze:'}, ...
                'SelectionMode', 'single', ...
                'ListString', available_cases, ...
                'InitialValue', default_index, ...
                'ListSize', [260, 120]);

            if ok_clicked ~= 1 || isempty(selected_index)
                error('run_combined_AVS_analysis_FINAL:AircraftSelectionCancelled', ...
                    'Aircraft case selection was cancelled. No analysis was run.');
            end

            aircraft_case = available_cases{selected_index};
            return;
        catch ME
            if strcmp(ME.identifier, 'run_combined_AVS_analysis_FINAL:AircraftSelectionCancelled')
                rethrow(ME);
            end

            warning('run_combined_AVS_analysis_FINAL:GuiSelectorUnavailable', ...
                ['GUI aircraft selector was not available (%s). ', ...
                 'Falling back to command-window selection.'], ME.message);
        end
    end

    fprintf('\nAvailable aircraft cases:\n');
    for k = 1:numel(available_cases)
        fprintf('  %d) %s\n', k, available_cases{k});
    end

    selected_index = input(sprintf('Select aircraft case number [%d]: ', default_index));
    if isempty(selected_index)
        selected_index = default_index;
    end

    if ~isscalar(selected_index) || selected_index < 1 || selected_index > numel(available_cases) || selected_index ~= round(selected_index)
        error('run_combined_AVS_analysis_FINAL:InvalidAircraftSelection', ...
            'Invalid aircraft case selection. No analysis was run.');
    end

    aircraft_case = available_cases{selected_index};
end

function available_cases = local_available_aircraft_cases(project_folder)
    available_cases = {};

    case_root = fullfile(project_folder, 'aircraft_cases');
    if isfolder(case_root)
        listing = dir(case_root);
        for k = 1:numel(listing)
            if ~listing(k).isdir
                continue;
            end

            folder_name = listing(k).name;
            if strcmp(folder_name, '.') || strcmp(folder_name, '..')
                continue;
            end

            candidate_folder = fullfile(case_root, folder_name);
            has_long_input = exist(fullfile(candidate_folder, 'AVSrun_analysis.m'), 'file') == 2;
            has_lat_input  = exist(fullfile(candidate_folder, 'AVS_input_lateral_current.m'), 'file') == 2;

            if has_long_input && has_lat_input
                available_cases{end+1} = local_case_tag(folder_name); %#ok<AGROW>
            end
        end
    end

    root_has_long_input = exist(fullfile(project_folder, 'AVSrun_analysis.m'), 'file') == 2;
    root_has_lat_input  = exist(fullfile(project_folder, 'AVS_input_lateral_current.m'), 'file') == 2;
    if root_has_long_input && root_has_lat_input && ~any(strcmpi(available_cases, 'NAVION'))
        available_cases{end+1} = 'NAVION';
    end

    available_cases = local_unique_case_list(available_cases);
    available_cases = local_prefer_case_first(available_cases, 'NAVION');
end

function cases_out = local_unique_case_list(cases_in)
    cases_out = {};
    for k = 1:numel(cases_in)
        candidate = local_case_tag(cases_in{k});
        if ~any(strcmpi(cases_out, candidate))
            cases_out{end+1} = candidate; %#ok<AGROW>
        end
    end
end

function cases_out = local_prefer_case_first(cases_in, preferred_case)
    preferred_tag = local_case_tag(preferred_case);
    cases_out = cases_in;

    idx = find(strcmpi(cases_out, preferred_tag), 1);
    if isempty(idx) || idx == 1
        return;
    end

    cases_out = [cases_out(idx), cases_out(1:idx-1), cases_out(idx+1:end)];
end

function case_folder = local_resolve_aircraft_case(project_folder, aircraft_case)
    case_tag = local_case_tag(aircraft_case);
    case_candidate = fullfile(project_folder, 'aircraft_cases', case_tag);

    if isfolder(case_candidate)
        case_folder = case_candidate;
    elseif strcmpi(case_tag, 'NAVION')
        % Legacy/default behavior: root-level NAVION files are still allowed.
        case_folder = project_folder;
    else
        error('run_combined_AVS_analysis_FINAL:MissingAircraftCaseFolder', ...
            ['Aircraft case folder was not found:\n  %s\n\n', ...
             'Create that folder or choose an available aircraft case.'], ...
            case_candidate);
    end

    long_input_file = fullfile(case_folder, 'AVSrun_analysis.m');
    lat_input_file  = fullfile(case_folder, 'AVS_input_lateral_current.m');

    if exist(long_input_file, 'file') ~= 2
        error('run_combined_AVS_analysis_FINAL:MissingLongitudinalInput', ...
            'Longitudinal input file was not found:\n  %s', long_input_file);
    end

    if exist(lat_input_file, 'file') ~= 2
        error('run_combined_AVS_analysis_FINAL:MissingLateralInput', ...
            'Lateral/directional input file was not found:\n  %s', lat_input_file);
    end
end

function results_folder = local_prepare_results_folder(project_folder, aircraft_case)
    case_tag = local_case_tag(aircraft_case);
    results_folder = fullfile(project_folder, 'results', case_tag);

    if ~isfolder(results_folder)
        mkdir(results_folder);
    end
end

function case_tag = local_case_tag(aircraft_case)
    if nargin < 1 || isempty(aircraft_case)
        aircraft_case = 'NAVION';
    end

    if isstring(aircraft_case)
        aircraft_case = char(aircraft_case);
    end

    case_tag = upper(strtrim(aircraft_case));
    case_tag = regexprep(case_tag, '[^A-Z0-9_]', '_');

    if isempty(case_tag)
        case_tag = 'NAVION';
    end
end

function [out_long, pAV_long, pSI_long, report_text] = local_run_longitudinal(case_folder, project_folder)
    old_folder = pwd;
    cleanup = onCleanup(@() cd(old_folder));
    addpath(project_folder);
    cd(case_folder);

    report_text = evalc('run(fullfile(case_folder, ''AVSrun_analysis.m''));');

    if ~exist('out', 'var')
        error('AVSrun_analysis.m did not create the expected variable `out`.');
    end
    if ~exist('pAV', 'var')
        error('AVSrun_analysis.m did not create the expected variable `pAV`.');
    end
    if ~exist('pSI', 'var')
        error('AVSrun_analysis.m did not create the expected variable `pSI`.');
    end

    out_long = out;
    pAV_long = pAV;
    pSI_long = pSI;
end

function [out_lat_result, pAV_lat, report_text] = local_run_lateral(case_folder, project_folder)
    old_folder = pwd;
    cleanup = onCleanup(@() cd(old_folder));
    addpath(project_folder);
    cd(case_folder);

    report_text = evalc('run(fullfile(case_folder, ''AVS_input_lateral_current.m''));');
    if ~exist('out_lat', 'var')
        error(['AVS_input_lateral_current.m did not create the expected ', ...
               'variable `out_lat`. Make sure its final line calls the lateral core.']);
    end
    if ~exist('pAV', 'var')
        error('AVS_input_lateral_current.m did not create the expected variable `pAV`.');
    end

    out_lat_result = out_lat;
    pAV_lat = pAV;
end

function local_export_combined_xlsx(out, xlsx_file)
    if exist(xlsx_file, 'file')
        delete(xlsx_file);
    end

    local_write_sheet(xlsx_file, 'Summary', local_make_summary_sheet(out));
    local_write_sheet(xlsx_file, 'Longitudinal_Output', local_struct_to_sheet(out.longitudinal, 'longitudinal'));
    local_write_sheet(xlsx_file, 'Lateral_Directional_Output', local_struct_to_sheet(out.lateral_directional, 'lateral_directional'));
    local_write_sheet(xlsx_file, 'Longitudinal_Input_AVS', local_struct_to_sheet(out.inputs.longitudinal_AVS, 'inputs.longitudinal_AVS'));
    local_write_sheet(xlsx_file, 'Longitudinal_Input_SI', local_struct_to_sheet(out.inputs.longitudinal_SI, 'inputs.longitudinal_SI'));
    local_write_sheet(xlsx_file, 'Lateral_Directional_Input_AVS', local_struct_to_sheet(out.inputs.lateral_directional_AVS, 'inputs.lateral_directional_AVS'));

    % New standardized SI/AVS input containers.
    % These duplicate some existing input information intentionally, but with
    % a cleaner structure for the unit-system expansion.
    local_write_sheet(xlsx_file, 'Inputs_AVS', local_struct_to_sheet(out.inputs_AVS, 'inputs_AVS'));
    local_write_sheet(xlsx_file, 'Inputs_SI', local_struct_to_sheet(out.inputs_SI, 'inputs_SI'));
        local_write_sheet(xlsx_file, 'Reports', local_make_reports_sheet(out));
end

function sheet = local_make_summary_sheet(out)
    sheet = {
        'Section', 'Item', 'Value';
        'Meta', 'Generated by', out.meta.file;
        'Meta', 'Aircraft case', local_value_to_text(local_getfield_safe(out.meta, 'aircraft_case'));
        'Meta', 'Aircraft', local_value_to_text(out.meta.aircraft);
        'Meta', 'Input units', out.meta.units_input;
        'Meta', 'Project folder', local_value_to_text(local_getfield_safe(out.meta, 'project_folder'));
        'Meta', 'Case folder', local_value_to_text(local_getfield_safe(out.meta, 'case_folder'));
        'Meta', 'Results folder', local_value_to_text(local_getfield_safe(out.meta, 'results_folder'));
        'Meta', 'Longitudinal core', out.meta.longitudinal_core;
        'Meta', 'Lateral/directional core', out.meta.lateral_directional_core;
        'Meta', 'Generated on', out.meta.created;
        'Guide', 'Workbook format', 'Nested structs are flattened using Path, Class, Size, Row, Col, Real, Imag, Text.';
        'Guide', 'Complex numbers', 'Complex values are split into Real and Imag columns.';
        'Guide', 'Matrices and vectors', 'Each element is written on a separate row with Row and Col indices.';
        'Guide', 'Text and unsupported values', 'Written in the Text column to avoid spreadsheet conversion errors.';
        };

    sheet = [sheet; local_summary_vector_rows('Longitudinal eigenvalue', out.summary.longitudinal_eigenvalues)];
    sheet = [sheet; local_summary_vector_rows('Lateral/directional eigenvalue', out.summary.lateral_directional_eigenvalues)];

    if isfield(out.summary, 'longitudinal_static_stability')
        sheet = [sheet; {'Longitudinal', 'Static stability struct', 'See Longitudinal_Output sheet: static_stability.*'}];
    end
    if isfield(out.summary, 'lateral_directional_static_stability')
        sheet = [sheet; {'Lateral/directional', 'Static stability struct', 'See Lateral_Directional_Output sheet: static_stability.*'}];
    end
end

function rows = local_summary_vector_rows(label, values)
    rows = {};
    if isempty(values)
        rows = {label, 'Eigenvalues', 'Not available'};
        return;
    end
    values = values(:);
    for k = 1:numel(values)
        rows(end+1, :) = {label, sprintf('#%d', k), local_value_to_text(values(k))}; %#ok<AGROW>
    end
end

function sheet = local_struct_to_sheet(s, root_name)
    header = {'Path', 'Class', 'Size', 'Row', 'Col', 'Real', 'Imag', 'Text'};
    rows = local_flatten_value(s, root_name);
    if isempty(rows)
        sheet = [header; {root_name, class(s), local_size_to_text(size(s)), [], [], [], [], 'Empty or unsupported value'}];
    else
        sheet = [header; rows];
    end
end

function rows = local_flatten_value(value, path)
    rows = {};

    if isstruct(value)
        if isscalar(value)
            names = fieldnames(value);
            if isempty(names)
                rows = {path, 'struct', '1x1', [], [], [], [], 'Empty struct'};
            else
                for k = 1:numel(names)
                    child_path = [path, '.', names{k}];
                    rows = [rows; local_flatten_value(value.(names{k}), child_path)]; %#ok<AGROW>
                end
            end
        else
            dims = size(value);
            for k = 1:numel(value)
                idx_text = local_linear_index_to_subscript_text(k, dims);
                child_path = sprintf('%s%s', path, idx_text);
                rows = [rows; local_flatten_value(value(k), child_path)]; %#ok<AGROW>
            end
        end
        return;
    end

    if isnumeric(value) || islogical(value)
        if isempty(value)
            rows = {path, class(value), local_size_to_text(size(value)), [], [], [], [], '[]'};
            return;
        end
        if ~ismatrix(value)
            rows = {path, class(value), local_size_to_text(size(value)), [], [], [], [], local_value_to_text(value)};
            return;
        end
        [nr, nc] = size(value);
        for r = 1:nr
            for c = 1:nc
                x = value(r, c);
                if islogical(x)
                    real_part = double(x);
                    imag_part = [];
                    text_part = logical_to_text(x);
                else
                    real_part = real(x);
                    imag_part = imag(x);
                    if imag_part == 0
                        imag_part = [];
                    end
                    text_part = '';
                end
                rows(end+1, :) = {path, class(value), local_size_to_text(size(value)), r, c, real_part, imag_part, text_part}; %#ok<AGROW>
            end
        end
        return;
    end

    if ischar(value)
        rows = {path, 'char', local_size_to_text(size(value)), [], [], [], [], value};
        return;
    end

    if isstring(value)
        if isempty(value)
            rows = {path, 'string', local_size_to_text(size(value)), [], [], [], [], '<empty string>'};
        else
            for k = 1:numel(value)
                rows(end+1, :) = {path, 'string', local_size_to_text(size(value)), k, [], [], [], char(value(k))}; %#ok<AGROW>
            end
        end
        return;
    end

    if iscell(value)
        if isempty(value)
            rows = {path, 'cell', local_size_to_text(size(value)), [], [], [], [], '{}'};
            return;
        end
        [nr, nc] = size(value);
        for r = 1:nr
            for c = 1:nc
                child_path = sprintf('%s{%d,%d}', path, r, c);
                rows = [rows; local_flatten_value(value{r, c}, child_path)]; %#ok<AGROW>
            end
        end
        return;
    end

    rows = {path, class(value), local_size_to_text(size(value)), [], [], [], [], local_value_to_text(value)};
end

function sheet = local_make_reports_sheet(out)
    header = {'Report', 'Line', 'Text'};
    rows = header;
    rows = [rows; local_report_lines('Longitudinal', out.reports.longitudinal)];
    rows = [rows; local_report_lines('Lateral/directional', out.reports.lateral_directional)];
    sheet = rows;
end

function rows = local_report_lines(report_name, report_text)
    rows = {};
    lines = regexp(report_text, '\r\n|\n|\r', 'split');
    for k = 1:numel(lines)
        rows(end+1, :) = {report_name, k, lines{k}}; %#ok<AGROW>
    end
end

function local_write_sheet(xlsx_file, sheet_name, content)
    content = local_normalize_cell_content(content);

    if exist('writecell', 'file') ~= 2
        error(['This MATLAB version does not provide writecell. ', ...
               'Cannot create XLSX workbook automatically.']);
    end

    writecell(content, xlsx_file, 'Sheet', sheet_name, 'Range', 'A1');
end

function content = local_normalize_cell_content(content)
    for r = 1:size(content, 1)
        for c = 1:size(content, 2)
            x = content{r, c};
            if isempty(x)
                content{r, c} = [];
            elseif isa(x, 'datetime')
                content{r, c} = char(x);
            elseif isa(x, 'duration')
                content{r, c} = char(x);
            elseif isa(x, 'categorical')
                content{r, c} = char(string(x));
            elseif isstring(x)
                if isscalar(x)
                    content{r, c} = char(x);
                else
                    content{r, c} = local_value_to_text(x);
                end
            elseif isnumeric(x)
                if ~isscalar(x) || ~isreal(x)
                    content{r, c} = local_value_to_text(x);
                end
            elseif islogical(x)
                if isscalar(x)
                    content{r, c} = logical_to_text(x);
                else
                    content{r, c} = local_value_to_text(x);
                end
            elseif ~(ischar(x))
                content{r, c} = local_value_to_text(x);
            end
        end
    end
end

function txt = local_value_to_text(value)
    if isempty(value)
        txt = '';
    elseif isnumeric(value)
        if isscalar(value)
            if isreal(value)
                txt = sprintf('%.15g', value);
            else
                txt = sprintf('%.15g%+.15gi', real(value), imag(value));
            end
        elseif ismatrix(value)
            txt = mat2str(value, 8);
        else
            txt = sprintf('<%s %s>', class(value), local_size_to_text(size(value)));
        end
    elseif islogical(value)
        if isscalar(value)
            txt = logical_to_text(value);
        else
            txt = mat2str(value);
        end
    elseif ischar(value)
        txt = value;
    elseif isstring(value)
        txt = strjoin(cellstr(value(:)), ', ');
    elseif iscell(value)
        txt = sprintf('<cell %s>', local_size_to_text(size(value)));
    elseif isstruct(value)
        txt = sprintf('<struct %s>', local_size_to_text(size(value)));
    else
        try
            txt = char(value);
        catch
            txt = sprintf('<%s %s>', class(value), local_size_to_text(size(value)));
        end
    end
end

function txt = logical_to_text(x)
    if x
        txt = 'true';
    else
        txt = 'false';
    end
end

function txt = local_size_to_text(sz)
    txt = sprintf('%dx', sz);
    txt = txt(1:end-1);
end

function idx_text = local_linear_index_to_subscript_text(k, dims)
    subs = cell(1, numel(dims));
    [subs{:}] = ind2sub(dims, k);
    pieces = cell(1, numel(dims));
    for q = 1:numel(dims)
        pieces{q} = sprintf('%d', subs{q});
    end
    idx_text = ['(', strjoin(pieces, ','), ')'];
end

function value = local_getfield_safe(s, field_name)
    if isstruct(s) && isfield(s, field_name)
        value = s.(field_name);
    else
        value = [];
    end
end

function value = local_first_existing(candidates)
    value = [];
    for k = 1:numel(candidates)
        candidate = candidates{k};
        if ~(isempty(candidate) || (isstring(candidate) && strlength(candidate) == 0))
            value = candidate;
            return;
        end
    end
end
