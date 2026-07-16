function param_out = run_parametric_sweep(long_pAV_base, lat_pAV_base, parameter_name, options)
% RUN_PARAMETRIC_SWEEP Run one-dimensional parametric sweeps using existing cores.
%
%   param_out = run_parametric_sweep(long_pAV_base, lat_pAV_base, parameter_name)
%   param_out = run_parametric_sweep(long_pAV_base, lat_pAV_base, parameter_name, options)
%
% Current implemented parameter
%   parameter_name = 'u_0'
%
% Purpose
%   This is the first backend sweep runner for the parametric-analysis phase.
%   It does not modify aircraft input files. It operates on copies of the
%   supplied baseline AVS input structs, calls apply_parametric_variation at
%   each accepted sweep value, and then runs the existing validated analysis
%   cores:
%
%       Longitudinal:        AVS_to_SI -> SI_longitudinal_analysis_grouped
%       Lateral/directional: AVS_lateral_directional_analysis
%
% Required baseline inputs
%   long_pAV_base : longitudinal AVS input struct from the selected case
%   lat_pAV_base  : lateral/directional AVS input struct from the selected case
%
% Typical use after running run_combined_AVS_analysis_FINAL.m
%   param_out = run_parametric_sweep(long_pAV, lat_pAV, 'u_0');
%   disp(param_out.summary_table)
%
% Options
%   options.analysis_branch       'both' (default), 'longitudinal', or 'lateral'
%   options.sweep_factors         forwarded to build_u0_sweep_values
%   options.mach_cap              forwarded to build_u0_sweep_values/apply helper
%   options.speed_of_sound_kt     optional explicit speed of sound
%   options.suppress_core_output  true by default; captures printed reports
%   options.continue_on_error     true by default; stores failures and continues
%   options.store_full_outputs    true by default for PA-2 validation
%   options.store_full_inputs     true by default for PA-2 validation
%
% Output
%   param_out.meta
%   param_out.sweep
%   param_out.summary_table
%   param_out.cases
%   param_out.matrices
%   param_out.eigenvalues
%   param_out.derivatives
%   param_out.reports
%   param_out.failures
%
% Notes
%   - No plots or Excel workbooks are generated in PA-2.
%   - The function is intentionally conservative and stores full outputs by
%     default so the first implementation can be validated thoroughly.

if nargin < 4 || isempty(options)
    options = struct();
end

if nargin < 3 || isempty(parameter_name)
    parameter_name = 'u_0';
end

if nargin < 2
    error('run_parametric_sweep:NotEnoughInputs', ...
        'Provide long_pAV_base, lat_pAV_base, and parameter_name.');
end

parameter_key = local_normalize_parameter_name(parameter_name);

analysis_branch = lower(strtrim(local_get_option(options, 'analysis_branch', 'both')));
run_longitudinal = any(strcmp(analysis_branch, {'both','longitudinal','long','longitudinal_only'}));
run_lateral = any(strcmp(analysis_branch, {'both','lateral','lat','lateral_directional','lateral_only'}));

if ~run_longitudinal && ~run_lateral
    error('run_parametric_sweep:InvalidAnalysisBranch', ...
        'options.analysis_branch must be ''both'', ''longitudinal'', or ''lateral''.');
end

suppress_core_output = local_get_option(options, 'suppress_core_output', true);
continue_on_error = local_get_option(options, 'continue_on_error', true);
store_full_outputs = local_get_option(options, 'store_full_outputs', true);
store_full_inputs = local_get_option(options, 'store_full_inputs', true);

switch parameter_key
    case {'u_0','u0'}
        sweep = build_u0_sweep_values(long_pAV_base, lat_pAV_base, options);
        sweep_values = sweep.accepted_u0_kt(:).';
    otherwise
        error('run_parametric_sweep:UnsupportedParameter', ...
            'Unsupported parametric parameter: %s', parameter_name);
end

n = numel(sweep_values);
if n < 1
    error('run_parametric_sweep:EmptySweep', ...
        'The accepted sweep vector is empty.');
end

param_out = struct();
param_out.meta = struct();
param_out.meta.file = mfilename;
param_out.meta.created = char(datetime('now'));
param_out.meta.parameter_name = sweep.parameter_name;
param_out.meta.analysis_branch = analysis_branch;
param_out.meta.backend_stage = 'PA-2 backend sweep runner';
param_out.meta.longitudinal_core = 'SI_longitudinal_analysis_grouped';
param_out.meta.lateral_directional_core = 'AVS_lateral_directional_analysis';
param_out.meta.notes = ['Script/function backend only. No aircraft input files ', ...
    'are modified. Existing validated cores are called at each sweep point.'];

param_out.sweep = sweep;
param_out.baseline = struct();
param_out.baseline.long_pAV = long_pAV_base;
param_out.baseline.lat_pAV = lat_pAV_base;

param_out.cases = repmat(local_empty_case_struct(), n, 1);
param_out.reports = struct();
param_out.reports.longitudinal = cell(n, 1);
param_out.reports.lateral_directional = cell(n, 1);
param_out.failures = repmat(local_empty_failure_struct(), 0, 1);

% Fixed-size matrix/eigenvalue storage for the current validated cores.
param_out.matrices = struct();
param_out.matrices.longitudinal = struct();
param_out.matrices.longitudinal.A = NaN(4, 4, n);
param_out.matrices.longitudinal.B = NaN(4, 2, n);
param_out.matrices.lateral_directional = struct();
param_out.matrices.lateral_directional.A = NaN(4, 4, n);
param_out.matrices.lateral_directional.B = NaN(4, 2, n);

param_out.eigenvalues = struct();
param_out.eigenvalues.longitudinal = NaN(4, n);
param_out.eigenvalues.lateral_directional = NaN(4, n);

param_out.derivatives = struct();
param_out.derivatives.longitudinal_nondim = cell(n, 1);
param_out.derivatives.longitudinal_dimensional = cell(n, 1);
param_out.derivatives.lateral_nondim = cell(n, 1);
param_out.derivatives.lateral_dimensional = cell(n, 1);

point_index = (1:n).';
u0_kt_col = NaN(n, 1);
factor_col = NaN(n, 1);
mach_col = NaN(n, 1);
long_CL0_col = NaN(n, 1);
lat_CL0_col = NaN(n, 1);
long_qbar_psf_col = NaN(n, 1);
lat_qbar_psf_col = NaN(n, 1);
long_max_real_col = NaN(n, 1);
lat_max_real_col = NaN(n, 1);
long_stable_col = false(n, 1);
lat_stable_col = false(n, 1);
long_ok_col = false(n, 1);
lat_ok_col = false(n, 1);
status_col = repmat({'not_run'}, n, 1);
warning_count_col = zeros(n, 1);

for k = 1:n
    current_value = sweep_values(k);
    case_status = 'ok';
    case_warnings = {};

    param_out.cases(k).index = k;
    param_out.cases(k).parameter_name = sweep.parameter_name;
    param_out.cases(k).parameter_value = current_value;
    param_out.cases(k).parameter_units = sweep.units;

    try
        [long_pAV_var, lat_pAV_var, variation_info] = apply_parametric_variation( ...
            long_pAV_base, lat_pAV_base, sweep.parameter_name, current_value, options);

        param_out.cases(k).variation_info = variation_info;
        case_warnings = [case_warnings, variation_info.warnings]; %#ok<AGROW>

        u0_kt_col(k) = variation_info.parameter_value_kt;
        factor_col(k) = variation_info.parameter_value_kt / variation_info.baseline_u0_kt;
        mach_col(k) = variation_info.mach;
        long_CL0_col(k) = variation_info.longitudinal.new_CL0;
        lat_CL0_col(k) = variation_info.lateral_directional.new_CL0;
        long_qbar_psf_col(k) = variation_info.longitudinal.new_qbar_psf;
        lat_qbar_psf_col(k) = variation_info.lateral_directional.new_qbar_psf;

        if store_full_inputs
            param_out.cases(k).inputs.longitudinal_AVS = long_pAV_var;
            param_out.cases(k).inputs.lateral_directional_AVS = lat_pAV_var;
        end

        if run_longitudinal
            try
                if suppress_core_output
                    report_text = evalc('[long_out_var, long_pSI_var] = local_run_longitudinal_core(long_pAV_var);');
                else
                    [long_out_var, long_pSI_var] = local_run_longitudinal_core(long_pAV_var);
                    report_text = '';
                end

                long_ok_col(k) = true;
                param_out.reports.longitudinal{k} = report_text;

                if store_full_inputs
                    param_out.cases(k).inputs.longitudinal_SI = long_pSI_var;
                end
                if store_full_outputs
                    param_out.cases(k).outputs.longitudinal = long_out_var;
                end

                [A_long, B_long, eig_long] = local_extract_longitudinal_state_space(long_out_var);
                param_out.matrices.longitudinal.A(:, :, k) = local_matrix_or_nan(A_long, 4, 4);
                param_out.matrices.longitudinal.B(:, :, k) = local_matrix_or_nan(B_long, 4, 2);
                param_out.eigenvalues.longitudinal(:, k) = local_vector_or_nan(eig_long, 4);

                param_out.derivatives.longitudinal_nondim{k} = local_scalar_struct_field(long_out_var, 'nondim');
                param_out.derivatives.longitudinal_dimensional{k} = local_scalar_struct_field(long_out_var, 'dimensional');

                long_max_real_col(k) = local_max_real_eigenvalue(eig_long);
                long_stable_col(k) = isfinite(long_max_real_col(k)) && long_max_real_col(k) < 0;

            catch ME_long
                case_status = 'partial_failure';
                param_out.failures(end+1) = local_make_failure(k, sweep.parameter_name, current_value, ...
                    'longitudinal', ME_long); %#ok<AGROW>
                if ~continue_on_error
                    rethrow(ME_long);
                end
            end
        end

        if run_lateral
            try
                if suppress_core_output
                    report_text = evalc('lat_out_var = AVS_lateral_directional_analysis(lat_pAV_var);');
                else
                    lat_out_var = AVS_lateral_directional_analysis(lat_pAV_var);
                    report_text = '';
                end

                lat_ok_col(k) = true;
                param_out.reports.lateral_directional{k} = report_text;

                if store_full_outputs
                    param_out.cases(k).outputs.lateral_directional = lat_out_var;
                end

                [A_lat, B_lat, eig_lat] = local_extract_lateral_state_space(lat_out_var);
                param_out.matrices.lateral_directional.A(:, :, k) = local_matrix_or_nan(A_lat, 4, 4);
                param_out.matrices.lateral_directional.B(:, :, k) = local_matrix_or_nan(B_lat, 4, 2);
                param_out.eigenvalues.lateral_directional(:, k) = local_vector_or_nan(eig_lat, 4);

                param_out.derivatives.lateral_nondim{k} = local_scalar_struct_field(lat_out_var, 'nondim');
                param_out.derivatives.lateral_dimensional{k} = local_scalar_struct_field(lat_out_var, 'dimensional');

                lat_max_real_col(k) = local_max_real_eigenvalue(eig_lat);
                lat_stable_col(k) = isfinite(lat_max_real_col(k)) && lat_max_real_col(k) < 0;

            catch ME_lat
                case_status = 'partial_failure';
                param_out.failures(end+1) = local_make_failure(k, sweep.parameter_name, current_value, ...
                    'lateral_directional', ME_lat); %#ok<AGROW>
                if ~continue_on_error
                    rethrow(ME_lat);
                end
            end
        end

    catch ME_apply
        case_status = 'failed';
        param_out.failures(end+1) = local_make_failure(k, sweep.parameter_name, current_value, ...
            'variation_helper', ME_apply); %#ok<AGROW>
        if ~continue_on_error
            rethrow(ME_apply);
        end
    end

    if ~isempty(case_warnings)
        param_out.cases(k).warnings = case_warnings;
    end
    warning_count_col(k) = numel(case_warnings);
    status_col{k} = case_status;
    param_out.cases(k).status = case_status;
end

baseline_index = local_find_baseline_index(sweep.accepted_u0_kt, sweep.baseline_u0_kt);
param_out.baseline.index = baseline_index;
if ~isnan(baseline_index)
    param_out.baseline.case = param_out.cases(baseline_index);
    if run_longitudinal
        param_out.baseline.longitudinal_eigenvalues = param_out.eigenvalues.longitudinal(:, baseline_index);
        param_out.baseline.longitudinal_A = param_out.matrices.longitudinal.A(:, :, baseline_index);
    end
    if run_lateral
        param_out.baseline.lateral_directional_eigenvalues = param_out.eigenvalues.lateral_directional(:, baseline_index);
        param_out.baseline.lateral_directional_A = param_out.matrices.lateral_directional.A(:, :, baseline_index);
    end
end

param_out.summary_table = table( ...
    point_index, ...
    u0_kt_col, ...
    factor_col, ...
    mach_col, ...
    long_CL0_col, ...
    lat_CL0_col, ...
    long_qbar_psf_col, ...
    lat_qbar_psf_col, ...
    long_max_real_col, ...
    lat_max_real_col, ...
    long_stable_col, ...
    lat_stable_col, ...
    long_ok_col, ...
    lat_ok_col, ...
    warning_count_col, ...
    status_col, ...
    'VariableNames', { ...
        'Point', ...
        'u0_kt', ...
        'SweepFactor', ...
        'Mach', ...
        'Long_CL0', ...
        'Lat_CL0', ...
        'Long_qbar_psf', ...
        'Lat_qbar_psf', ...
        'Long_MaxRealEig', ...
        'Lat_MaxRealEig', ...
        'Long_DynamicallyStable', ...
        'Lat_DynamicallyStable', ...
        'Long_RunOK', ...
        'Lat_RunOK', ...
        'WarningCount', ...
        'Status'});

end

function [long_out, long_pSI] = local_run_longitudinal_core(long_pAV)
long_pSI = AVS_to_SI(long_pAV);
long_out = SI_longitudinal_analysis_grouped(long_pSI);
end

function [A, B, eigvals] = local_extract_longitudinal_state_space(long_out)
A = NaN;
B = NaN;
eigvals = NaN;

if isstruct(long_out)
    if isfield(long_out, 'state_space') && isstruct(long_out.state_space)
        if isfield(long_out.state_space, 'A')
            A = long_out.state_space.A;
        end
        if isfield(long_out.state_space, 'B')
            B = long_out.state_space.B;
        end
        if isfield(long_out.state_space, 'eigenvalues')
            eigvals = long_out.state_space.eigenvalues;
        end
    end
    if ~(isnumeric(A) && isequal(size(A), [4 4])) && isfield(long_out, 'A')
        A = long_out.A;
    end
    if ~(isnumeric(B) && isequal(size(B), [4 2])) && isfield(long_out, 'B')
        B = long_out.B;
    end
    if ~(isnumeric(eigvals) && numel(eigvals) == 4) && isfield(long_out, 'eigA')
        eigvals = long_out.eigA;
    end
end
end

function [A, B, eigvals] = local_extract_lateral_state_space(lat_out)
A = NaN;
B = NaN;
eigvals = NaN;

if isstruct(lat_out) && isfield(lat_out, 'state_space') && isstruct(lat_out.state_space)
    if isfield(lat_out.state_space, 'A_lat')
        A = lat_out.state_space.A_lat;
    elseif isfield(lat_out.state_space, 'A')
        A = lat_out.state_space.A;
    end
    if isfield(lat_out.state_space, 'B_lat')
        B = lat_out.state_space.B_lat;
    elseif isfield(lat_out.state_space, 'B')
        B = lat_out.state_space.B;
    end
    if isfield(lat_out.state_space, 'eigenvalues')
        eigvals = lat_out.state_space.eigenvalues;
    elseif isfield(lat_out, 'modes_exact') && isfield(lat_out.modes_exact, 'eigenvalues')
        eigvals = lat_out.modes_exact.eigenvalues;
    end
elseif isstruct(lat_out) && isfield(lat_out, 'modes_exact') && isfield(lat_out.modes_exact, 'eigenvalues')
    eigvals = lat_out.modes_exact.eigenvalues;
end
end

function S = local_scalar_struct_field(parent, field_name)
S = struct();
if ~isstruct(parent) || ~isfield(parent, field_name) || ~isstruct(parent.(field_name))
    return;
end

src = parent.(field_name);
fields = fieldnames(src);
for k = 1:numel(fields)
    f = fields{k};
    v = src.(f);
    if isnumeric(v) && isscalar(v) && isfinite(v)
        S.(f) = v;
    elseif islogical(v) && isscalar(v)
        S.(f) = v;
    end
end
end

function Mout = local_matrix_or_nan(Min, nrow, ncol)
Mout = NaN(nrow, ncol);
if isnumeric(Min) && isequal(size(Min), [nrow ncol])
    Mout = Min;
end
end

function vout = local_vector_or_nan(vin, n)
vout = NaN(n, 1);
if isnumeric(vin) && numel(vin) >= n
    vtmp = vin(:);
    vout = vtmp(1:n);
end
end

function value = local_max_real_eigenvalue(eigvals)
value = NaN;
if isnumeric(eigvals) && ~isempty(eigvals)
    eigvals = eigvals(:);
    if all(isfinite(real(eigvals))) && all(isfinite(imag(eigvals)))
        value = max(real(eigvals));
    end
end
end

function idx = local_find_baseline_index(values, baseline_value)
idx = NaN;
if ~isnumeric(values) || isempty(values) || ~isfinite(baseline_value)
    return;
end
[diff_value, i] = min(abs(values(:) - baseline_value));
tol = max(1.0e-10, 1.0e-10 * abs(baseline_value));
if isfinite(diff_value) && diff_value <= tol
    idx = i;
end
end

function key = local_normalize_parameter_name(name_in)
key = lower(strtrim(name_in));
key = strrep(key, ' ', '');
key = strrep(key, '-', '_');
end

function value = local_get_option(options, field_name, default_value)
if isstruct(options) && isfield(options, field_name) && ~isempty(options.(field_name))
    value = options.(field_name);
else
    value = default_value;
end
end

function c = local_empty_case_struct()
c = struct();
c.index = NaN;
c.parameter_name = '';
c.parameter_value = NaN;
c.parameter_units = '';
c.variation_info = struct();
c.inputs = struct();
c.outputs = struct();
c.warnings = {};
c.status = 'not_run';
end

function f = local_empty_failure_struct()
f = struct();
f.index = NaN;
f.parameter_name = '';
f.parameter_value = NaN;
f.branch = '';
f.identifier = '';
f.message = '';
end

function f = local_make_failure(index, parameter_name, parameter_value, branch, ME)
f = struct();
f.index = index;
f.parameter_name = parameter_name;
f.parameter_value = parameter_value;
f.branch = branch;
f.identifier = ME.identifier;
f.message = ME.message;
end
