function workbook_file = export_parametric_workbook(param_out, workbook_file, options)
% EXPORT_PARAMETRIC_WORKBOOK Export parametric-sweep results to an Excel workbook.
%
%   workbook_file = export_parametric_workbook(param_out)
%   workbook_file = export_parametric_workbook(param_out, workbook_file)
%   workbook_file = export_parametric_workbook(param_out, workbook_file, options)
%
% Purpose
%   Export layer for the parametric-analysis workflow. This function writes
%   the results returned by run_parametric_sweep.m to a workbook. It does
%   not rerun any analysis and does not modify aircraft input files.
%
% Implemented parameters
%   u_0   : exports dynamic sweep outputs, eigenvalues, matrices,
%           derivatives, warnings, and failures.
%   x_cg  : also exports static-stability columns, primary/secondary static
%           classification, method-agreement flags, and critical-CG metadata.
%
% Options
%   options.overwrite_existing  true by default
%
% Notes
%   - Complex eigenvalues are exported as real/imaginary columns.
%   - Matrix entries are exported in long/table form, including baseline
%     difference and percent change where a baseline entry is available.

if nargin < 3 || isempty(options)
    options = struct();
end

if nargin < 2 || isempty(workbook_file)
    parameter_name = local_get_nested_text(param_out, {'sweep','parameter_name'}, 'parameter');
    workbook_file = sprintf('parametric_%s_results.xlsx', local_sanitize_filename(parameter_name));
end

if nargin < 1 || ~isstruct(param_out)
    error('export_parametric_workbook:InvalidInput', ...
        'Provide param_out returned by run_parametric_sweep.m.');
end

overwrite_existing = local_get_option(options, 'overwrite_existing', true);
if overwrite_existing && exist(workbook_file, 'file')
    delete(workbook_file);
end

% Summary.
if isfield(param_out, 'summary_table') && istable(param_out.summary_table)
    writetable(param_out.summary_table, workbook_file, 'Sheet', 'Summary');
else
    writetable(table({'No summary_table field found.'}, 'VariableNames', {'Message'}), ...
        workbook_file, 'Sheet', 'Summary');
end

% Sweep definition, baseline, and x_cg static-stability metadata.
writetable(local_sweep_table(param_out), workbook_file, 'Sheet', 'Sweep_Definition');
writetable(local_baseline_table(param_out), workbook_file, 'Sheet', 'Baseline');
writetable(local_static_stability_table(param_out), workbook_file, 'Sheet', 'Static_Stability');

% Eigenvalues.
writetable(local_eigenvalue_table(param_out, 'longitudinal'), ...
    workbook_file, 'Sheet', 'Longitudinal_Eigenvalues');
writetable(local_eigenvalue_table(param_out, 'lateral_directional'), ...
    workbook_file, 'Sheet', 'Lateral_Eigenvalues');

% Matrices.
writetable(local_matrix_entry_table(param_out, 'longitudinal', 'A'), ...
    workbook_file, 'Sheet', 'A_Long_Entries');
writetable(local_matrix_entry_table(param_out, 'lateral_directional', 'A'), ...
    workbook_file, 'Sheet', 'A_Lat_Entries');
writetable(local_matrix_entry_table(param_out, 'longitudinal', 'B'), ...
    workbook_file, 'Sheet', 'B_Long_Entries');
writetable(local_matrix_entry_table(param_out, 'lateral_directional', 'B'), ...
    workbook_file, 'Sheet', 'B_Lat_Entries');

% Derivatives/available scalar outputs.
writetable(local_cell_struct_table(param_out, {'derivatives','longitudinal_nondim'}, 'longitudinal_nondim'), ...
    workbook_file, 'Sheet', 'Longitudinal_Nondim');
writetable(local_cell_struct_table(param_out, {'derivatives','longitudinal_dimensional'}, 'longitudinal_dimensional'), ...
    workbook_file, 'Sheet', 'Longitudinal_Dimensional');
writetable(local_cell_struct_table(param_out, {'derivatives','lateral_nondim'}, 'lateral_nondim'), ...
    workbook_file, 'Sheet', 'Lateral_Nondim');
writetable(local_cell_struct_table(param_out, {'derivatives','lateral_dimensional'}, 'lateral_dimensional'), ...
    workbook_file, 'Sheet', 'Lateral_Dimensional');

% Warnings and failures.
writetable(local_warnings_table(param_out), workbook_file, 'Sheet', 'Warnings');
writetable(local_failures_table(param_out), workbook_file, 'Sheet', 'Failures');

end

function T = local_sweep_table(param_out)
rows = {};
if isfield(param_out, 'meta') && isstruct(param_out.meta)
    rows = [rows; local_struct_rows(param_out.meta, 'meta')]; %#ok<AGROW>
end
if isfield(param_out, 'sweep') && isstruct(param_out.sweep)
    rows = [rows; local_struct_rows(param_out.sweep, 'sweep')]; %#ok<AGROW>
end
if isempty(rows)
    rows = {'none','none','No sweep metadata found.'};
end
T = cell2table(rows, 'VariableNames', {'Source','Quantity','Value'});
end

function T = local_baseline_table(param_out)
rows = {};
if isfield(param_out, 'baseline') && isstruct(param_out.baseline)
    rows = [rows; local_struct_rows(param_out.baseline, 'baseline')]; %#ok<AGROW>
end
if isempty(rows)
    rows = {'none','none','No baseline metadata found.'};
end
T = cell2table(rows, 'VariableNames', {'Source','Quantity','Value'});
end

function T = local_static_stability_table(param_out)
rows = {};
if isfield(param_out, 'static_stability') && isstruct(param_out.static_stability)
    rows = [rows; local_struct_rows(param_out.static_stability, 'static_stability')]; %#ok<AGROW>
end

summary = local_get_summary(param_out);
if ~isempty(summary) && istable(summary)
    wanted = { ...
        'Point', ...
        'ParameterValue', ...
        'cg_mac', ...
        'Delta_cg_mac', ...
        'x_cg_ft', ...
        'lt_ft', ...
        'V_H', ...
        'Cm_alpha', ...
        'dCm_dCL', ...
        'StaticMargin_CmAlpha', ...
        'StaticMargin_NP', ...
        'x_NP_mac', ...
        'x_NP_from_CmAlpha_mac', ...
        'StaticStability_Primary', ...
        'StaticStability_PrimaryMethod', ...
        'StaticStability_Secondary_NP', ...
        'StaticStability_MethodAgreement', ...
        'WarningCount', ...
        'Long_MaxRealEig', ...
        'Long_DynamicallyStable', ...
        'Status'};
    present = wanted(ismember(wanted, summary.Properties.VariableNames));
    for i = 1:height(summary)
        source_name = sprintf('point_%d', i);
        for j = 1:numel(present)
            f = present{j};
            rows(end+1,:) = {source_name, f, local_table_value_to_text(summary, f, i)}; %#ok<AGROW>
        end
    end
end

if isempty(rows)
    rows = {'none','none','No static-stability metadata found.'};
end
T = cell2table(rows, 'VariableNames', {'Source','Quantity','Value'});
end

function rows = local_struct_rows(s, source_name)
rows = {};
fields = fieldnames(s);
for k = 1:numel(fields)
    f = fields{k};
    v = s.(f);
    if isnumeric(v) || islogical(v)
        if isscalar(v)
            rows(end+1,:) = {source_name, f, local_value_to_text(v)}; %#ok<AGROW>
        elseif isvector(v) && numel(v) <= 40
            rows(end+1,:) = {source_name, f, local_value_to_text(v(:).')}; %#ok<AGROW>
        else
            rows(end+1,:) = {source_name, f, sprintf('[%s %s]', num2str(size(v,1)), num2str(size(v,2)))}; %#ok<AGROW>
        end
    elseif ischar(v) || isstring(v)
        rows(end+1,:) = {source_name, f, char(v)}; %#ok<AGROW>
    elseif iscell(v)
        rows(end+1,:) = {source_name, f, sprintf('cell array, %d item(s)', numel(v))}; %#ok<AGROW>
    elseif isstruct(v)
        rows(end+1,:) = {source_name, f, 'struct'}; %#ok<AGROW>
    else
        rows(end+1,:) = {source_name, f, class(v)}; %#ok<AGROW>
    end
end
end

function T = local_eigenvalue_table(param_out, branch_name)
branch = {};
point = [];
parameter_value = [];
u0_kt = [];
sweep_factor = [];
cg_mac = [];
x_cg_ft = [];
mode_index = [];
real_part = [];
imag_part = [];
abs_value = [];

[eig_matrix, branch_label] = local_get_eigen_matrix(param_out, branch_name);
summary = local_get_summary(param_out);

if isempty(eig_matrix)
    T = table({'No eigenvalue data found.'}, 'VariableNames', {'Message'});
    return;
end

n = size(eig_matrix, 2);
for k = 1:n
    eigvals = eig_matrix(:, k);
    for j = 1:numel(eigvals)
        branch{end+1,1} = branch_label; %#ok<AGROW>
        point(end+1,1) = k; %#ok<AGROW>
        parameter_value(end+1,1) = local_summary_value(summary, 'ParameterValue', k); %#ok<AGROW>
        u0_kt(end+1,1) = local_summary_value(summary, 'u0_kt', k); %#ok<AGROW>
        sweep_factor(end+1,1) = local_summary_value(summary, 'SweepFactor', k); %#ok<AGROW>
        cg_mac(end+1,1) = local_summary_value(summary, 'cg_mac', k); %#ok<AGROW>
        x_cg_ft(end+1,1) = local_summary_value(summary, 'x_cg_ft', k); %#ok<AGROW>
        mode_index(end+1,1) = j; %#ok<AGROW>
        real_part(end+1,1) = real(eigvals(j)); %#ok<AGROW>
        imag_part(end+1,1) = imag(eigvals(j)); %#ok<AGROW>
        abs_value(end+1,1) = abs(eigvals(j)); %#ok<AGROW>
    end
end

T = table(branch, point, parameter_value, u0_kt, sweep_factor, cg_mac, x_cg_ft, ...
    mode_index, real_part, imag_part, abs_value, ...
    'VariableNames', {'Branch','Point','ParameterValue','u0_kt','SweepFactor','cg_mac','x_cg_ft', ...
    'EigenvalueIndex','Real','Imag','Magnitude'});
end

function T = local_matrix_entry_table(param_out, branch_name, matrix_name)
summary = local_get_summary(param_out);
M = local_get_matrix(param_out, branch_name, matrix_name);
if isempty(M)
    T = table({'No matrix data found.'}, 'VariableNames', {'Message'});
    return;
end

baseline_idx = local_get_baseline_index(param_out);
[nrow, ncol, n] = size(M);

branch = {};
point = [];
parameter_value = [];
u0_kt = [];
sweep_factor = [];
cg_mac = [];
x_cg_ft = [];
row_index = [];
col_index = [];
entry_name = {};
value = [];
baseline_value = [];
delta = [];
percent_change = [];

for k = 1:n
    for i = 1:nrow
        for j = 1:ncol
            current_value = M(i,j,k);
            if ~isnan(baseline_idx)
                base_value = M(i,j,baseline_idx);
            else
                base_value = NaN;
            end
            d = current_value - base_value;
            if isfinite(base_value) && abs(base_value) > eps
                pct = 100.0 * d / base_value;
            else
                pct = NaN;
            end

            branch{end+1,1} = branch_name; %#ok<AGROW>
            point(end+1,1) = k; %#ok<AGROW>
            parameter_value(end+1,1) = local_summary_value(summary, 'ParameterValue', k); %#ok<AGROW>
            u0_kt(end+1,1) = local_summary_value(summary, 'u0_kt', k); %#ok<AGROW>
            sweep_factor(end+1,1) = local_summary_value(summary, 'SweepFactor', k); %#ok<AGROW>
            cg_mac(end+1,1) = local_summary_value(summary, 'cg_mac', k); %#ok<AGROW>
            x_cg_ft(end+1,1) = local_summary_value(summary, 'x_cg_ft', k); %#ok<AGROW>
            row_index(end+1,1) = i; %#ok<AGROW>
            col_index(end+1,1) = j; %#ok<AGROW>
            entry_name{end+1,1} = sprintf('%s(%d,%d)', matrix_name, i, j); %#ok<AGROW>
            value(end+1,1) = current_value; %#ok<AGROW>
            baseline_value(end+1,1) = base_value; %#ok<AGROW>
            delta(end+1,1) = d; %#ok<AGROW>
            percent_change(end+1,1) = pct; %#ok<AGROW>
        end
    end
end

T = table(branch, point, parameter_value, u0_kt, sweep_factor, cg_mac, x_cg_ft, ...
    row_index, col_index, entry_name, value, baseline_value, delta, percent_change, ...
    'VariableNames', {'Branch','Point','ParameterValue','u0_kt','SweepFactor','cg_mac','x_cg_ft', ...
    'MatrixRow','MatrixColumn','Entry','Value','BaselineValue','Delta','PercentChange'});
end

function T = local_cell_struct_table(param_out, field_path, branch_label)
C = local_get_nested_value(param_out, field_path);
summary = local_get_summary(param_out);

if isempty(C) || ~iscell(C)
    T = table({'No derivative/scalar struct data found.'}, 'VariableNames', {'Message'});
    return;
end

all_fields = {};
for k = 1:numel(C)
    if isstruct(C{k})
        all_fields = union(all_fields, fieldnames(C{k}));
    end
end

if isempty(all_fields)
    T = table({'No scalar fields found.'}, 'VariableNames', {'Message'});
    return;
end

n = numel(C);
T = table((1:n).', 'VariableNames', {'Point'});
T.Branch = repmat({branch_label}, n, 1);
T.ParameterValue = NaN(n, 1);
T.u0_kt = NaN(n, 1);
T.SweepFactor = NaN(n, 1);
T.cg_mac = NaN(n, 1);
T.x_cg_ft = NaN(n, 1);
for k = 1:n
    T.ParameterValue(k) = local_summary_value(summary, 'ParameterValue', k);
    T.u0_kt(k) = local_summary_value(summary, 'u0_kt', k);
    T.SweepFactor(k) = local_summary_value(summary, 'SweepFactor', k);
    T.cg_mac(k) = local_summary_value(summary, 'cg_mac', k);
    T.x_cg_ft(k) = local_summary_value(summary, 'x_cg_ft', k);
end

for fidx = 1:numel(all_fields)
    f = all_fields{fidx};
    col = NaN(n, 1);
    for k = 1:n
        if isstruct(C{k}) && isfield(C{k}, f) && isnumeric(C{k}.(f)) && isscalar(C{k}.(f))
            col(k) = C{k}.(f);
        elseif isstruct(C{k}) && isfield(C{k}, f) && islogical(C{k}.(f)) && isscalar(C{k}.(f))
            col(k) = double(C{k}.(f));
        end
    end
    T.(matlab.lang.makeValidName(f)) = col;
end
end

function T = local_warnings_table(param_out)
source = {};
point = [];
message = {};

if isfield(param_out, 'sweep') && isstruct(param_out.sweep) && isfield(param_out.sweep, 'warnings')
    w = param_out.sweep.warnings;
    for k = 1:numel(w)
        source{end+1,1} = 'sweep'; %#ok<AGROW>
        point(end+1,1) = NaN; %#ok<AGROW>
        message{end+1,1} = char(w{k}); %#ok<AGROW>
    end
end

if isfield(param_out, 'cases')
    for k = 1:numel(param_out.cases)
        if isfield(param_out.cases(k), 'warnings') && ~isempty(param_out.cases(k).warnings)
            for j = 1:numel(param_out.cases(k).warnings)
                source{end+1,1} = 'case'; %#ok<AGROW>
                point(end+1,1) = k; %#ok<AGROW>
                message{end+1,1} = char(param_out.cases(k).warnings{j}); %#ok<AGROW>
            end
        end
    end
end

if isempty(source)
    source = {'none'};
    point = NaN;
    message = {'no warnings'};
end

T = table(source, point, message, 'VariableNames', {'Source','Point','Message'});
end

function T = local_failures_table(param_out)
if isfield(param_out, 'failures') && ~isempty(param_out.failures)
    F = param_out.failures(:);
    n = numel(F);
    index = NaN(n,1);
    parameter_name = cell(n,1);
    parameter_value = NaN(n,1);
    branch = cell(n,1);
    identifier = cell(n,1);
    message = cell(n,1);
    for k = 1:n
        index(k) = local_struct_num(F(k), 'index');
        parameter_name{k} = local_struct_text(F(k), 'parameter_name');
        parameter_value(k) = local_struct_num(F(k), 'parameter_value');
        branch{k} = local_struct_text(F(k), 'branch');
        identifier{k} = local_struct_text(F(k), 'identifier');
        message{k} = local_struct_text(F(k), 'message');
    end
    T = table(index, parameter_name, parameter_value, branch, identifier, message, ...
        'VariableNames', {'Point','ParameterName','ParameterValue','Branch','Identifier','Message'});
else
    T = table({'none'}, {'no failures'}, 'VariableNames', {'Status','Message'});
end
end

function [E, label] = local_get_eigen_matrix(param_out, branch_name)
E = [];
label = branch_name;
if ~isfield(param_out, 'eigenvalues') || ~isstruct(param_out.eigenvalues)
    return;
end
switch branch_name
    case 'longitudinal'
        if isfield(param_out.eigenvalues, 'longitudinal')
            E = param_out.eigenvalues.longitudinal;
            label = 'longitudinal';
        end
    case 'lateral_directional'
        if isfield(param_out.eigenvalues, 'lateral_directional')
            E = param_out.eigenvalues.lateral_directional;
            label = 'lateral_directional';
        end
end
if ~isempty(E) && ~any(isfinite(real(E(:))) | isfinite(imag(E(:))))
    E = [];
end
end

function M = local_get_matrix(param_out, branch_name, matrix_name)
M = [];
if ~isfield(param_out, 'matrices') || ~isstruct(param_out.matrices)
    return;
end
if ~isfield(param_out.matrices, branch_name) || ~isstruct(param_out.matrices.(branch_name))
    return;
end
if isfield(param_out.matrices.(branch_name), matrix_name)
    M = param_out.matrices.(branch_name).(matrix_name);
end
if ~isempty(M) && ~any(isfinite(M(:)))
    M = [];
end
end

function summary = local_get_summary(param_out)
summary = table();
if isfield(param_out, 'summary_table') && istable(param_out.summary_table)
    summary = param_out.summary_table;
end
end

function value = local_summary_value(summary, field_name, row_index)
value = NaN;
if istable(summary) && ismember(field_name, summary.Properties.VariableNames) && row_index <= height(summary)
    v = summary.(field_name);
    if isnumeric(v) || islogical(v)
        value = double(v(row_index));
    end
end
end

function idx = local_get_baseline_index(param_out)
idx = NaN;
if isfield(param_out, 'baseline') && isstruct(param_out.baseline) && ...
        isfield(param_out.baseline, 'index') && isnumeric(param_out.baseline.index) && isscalar(param_out.baseline.index)
    idx = param_out.baseline.index;
end
end

function value = local_get_option(options, field_name, default_value)
if isstruct(options) && isfield(options, field_name) && ~isempty(options.(field_name))
    value = options.(field_name);
else
    value = default_value;
end
end

function value = local_get_nested_value(s, path_parts)
value = [];
current = s;
for k = 1:numel(path_parts)
    if isstruct(current) && isfield(current, path_parts{k})
        current = current.(path_parts{k});
    else
        return;
    end
end
value = current;
end

function text_value = local_get_nested_text(s, path_parts, default_value)
value = local_get_nested_value(s, path_parts);
if ischar(value) || isstring(value)
    text_value = char(value);
else
    text_value = default_value;
end
end

function out = local_table_value_to_text(T, field_name, row_index)
v = T.(field_name)(row_index,:);
if iscell(v)
    if isempty(v)
        out = '';
    else
        out = local_table_cell_to_text(v{1});
    end
else
    out = local_table_cell_to_text(v);
end
end

function out = local_table_cell_to_text(v)
if isnumeric(v) || islogical(v)
    out = local_value_to_text(v);
elseif ischar(v) || isstring(v)
    out = char(v);
elseif iscell(v)
    if isempty(v)
        out = '';
    else
        out = local_table_cell_to_text(v{1});
    end
else
    out = class(v);
end
end

function out = local_value_to_text(v)
if isnumeric(v) || islogical(v)
    if isscalar(v)
        if islogical(v)
            out = char(string(v));
        else
            out = sprintf('%.15g', v);
        end
    else
        out = strtrim(sprintf('%.15g ', v));
    end
elseif ischar(v) || isstring(v)
    out = char(v);
else
    out = class(v);
end
end

function value = local_struct_num(s, field_name)
value = NaN;
if isstruct(s) && isfield(s, field_name) && isnumeric(s.(field_name)) && isscalar(s.(field_name))
    value = s.(field_name);
end
end

function value = local_struct_text(s, field_name)
value = '';
if isstruct(s) && isfield(s, field_name)
    v = s.(field_name);
    if ischar(v) || isstring(v)
        value = char(v);
    elseif isnumeric(v) || islogical(v)
        value = local_value_to_text(v);
    else
        value = class(v);
    end
end
end

function safe = local_sanitize_filename(text_in)
safe = regexprep(char(text_in), '[^A-Za-z0-9_\-]', '_');
if isempty(safe)
    safe = 'parameter';
end
end
