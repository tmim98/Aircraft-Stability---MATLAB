function param_out = run_parametric_sweep(long_pAV_base, lat_pAV_base, parameter_name, options)
% RUN_PARAMETRIC_SWEEP Run one-dimensional parametric sweeps using existing cores.
%
%   param_out = run_parametric_sweep(long_pAV_base, lat_pAV_base, parameter_name)
%   param_out = run_parametric_sweep(long_pAV_base, lat_pAV_base, parameter_name, options)
%
% Current implemented parameters
%   parameter_name = 'u_0'
%   parameter_name = 'x_cg'  (swept as cg_mac = x_cg/c_bar)
%
% Static stability policy for x_cg
%   Primary method: Cm_alpha / dCm_dCL
%   Secondary method: neutral-point static margin
%   Method disagreements are shown and flagged; they are not hidden.
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
%   param_out = run_parametric_sweep(long_pAV, lat_pAV, 'x_cg');
%   disp(param_out.summary_table)
%
% Options
%   options.analysis_branch       'both', 'longitudinal', or 'lateral'
%                                 default is 'both' for u_0 and
%                                 'longitudinal' for x_cg
%   options.sweep_factors         forwarded to build_u0_sweep_values
%   options.cg_mac_range          forwarded to build_xcg_sweep_values
%   options.cg_mac_min/max        forwarded to build_xcg_sweep_values/apply helper
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
%   - No plots or Excel workbooks are generated here.
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

default_analysis_branch = local_default_analysis_branch(parameter_key);
analysis_branch = lower(strtrim(local_get_option(options, 'analysis_branch', default_analysis_branch)));
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
    case {'x_cg','xcg','cg_mac','cgmac'}
        sweep = build_xcg_sweep_values(long_pAV_base, lat_pAV_base, options);
        sweep_values = sweep.accepted_cg_mac(:).';
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
param_out.meta.backend_stage = 'PA-6B backend sweep runner';
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
parameter_value_col = NaN(n, 1);
u0_kt_col = NaN(n, 1);
factor_col = NaN(n, 1);
mach_col = NaN(n, 1);
xcg_cg_mac_col = NaN(n, 1);
xcg_delta_mac_col = NaN(n, 1);
xcg_xcg_ft_col = NaN(n, 1);
xcg_lt_ft_col = NaN(n, 1);
xcg_VH_col = NaN(n, 1);
cm_alpha_col = NaN(n, 1);
dcm_dcl_col = NaN(n, 1);
static_margin_np_col = NaN(n, 1);
static_margin_cmalpha_col = NaN(n, 1);
x_np_mac_col = NaN(n, 1);
x_np_from_cmalpha_mac_col = NaN(n, 1);
static_stability_primary_col = repmat({'not_run'}, n, 1);
static_stability_primary_method_col = repmat({'Cm_alpha / dCm_dCL'}, n, 1);
static_stability_secondary_np_col = repmat({'not_run'}, n, 1);
static_stability_agreement_col = false(n, 1);
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
    parameter_value_col(k) = current_value;
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

        if isfield(variation_info, 'parameter_value_kt')
            u0_kt_col(k) = variation_info.parameter_value_kt;
            factor_col(k) = variation_info.parameter_value_kt / variation_info.baseline_u0_kt;
        end
        if isfield(variation_info, 'mach')
            mach_col(k) = variation_info.mach;
        end
        if isfield(variation_info, 'longitudinal') && isfield(variation_info.longitudinal, 'new_CL0')
            long_CL0_col(k) = variation_info.longitudinal.new_CL0;
        end
        if isfield(variation_info, 'lateral_directional') && isfield(variation_info.lateral_directional, 'new_CL0')
            lat_CL0_col(k) = variation_info.lateral_directional.new_CL0;
        end
        if isfield(variation_info, 'longitudinal') && isfield(variation_info.longitudinal, 'new_qbar_psf')
            long_qbar_psf_col(k) = variation_info.longitudinal.new_qbar_psf;
        end
        if isfield(variation_info, 'lateral_directional') && isfield(variation_info.lateral_directional, 'new_qbar_psf')
            lat_qbar_psf_col(k) = variation_info.lateral_directional.new_qbar_psf;
        end
        if isfield(variation_info, 'parameter_value_cg_mac')
            xcg_cg_mac_col(k) = variation_info.parameter_value_cg_mac;
            xcg_delta_mac_col(k) = variation_info.parameter_value_cg_mac - variation_info.baseline_cg_mac;
        end
        if isfield(variation_info, 'parameter_value_x_cg_ft')
            xcg_xcg_ft_col(k) = variation_info.parameter_value_x_cg_ft;
        end
        if isfield(variation_info, 'new_lt_ft')
            xcg_lt_ft_col(k) = variation_info.new_lt_ft;
        end
        if isfield(variation_info, 'new_V_H')
            xcg_VH_col(k) = variation_info.new_V_H;
        end

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

                static_info = local_extract_longitudinal_static_info(long_out_var);
                cm_alpha_col(k) = static_info.Cm_alpha;
                dcm_dcl_col(k) = static_info.dCm_dCL;
                static_margin_np_col(k) = static_info.static_margin_from_neutral_point;
                static_margin_cmalpha_col(k) = static_info.static_margin_from_Cm_alpha;
                x_np_mac_col(k) = static_info.x_NP_by_c;
                x_np_from_cmalpha_mac_col(k) = static_info.x_NP_by_c_from_Cm_alpha;
                static_stability_primary_col{k} = static_info.static_stability_primary;
                static_stability_primary_method_col{k} = static_info.static_stability_primary_method;
                static_stability_secondary_np_col{k} = static_info.static_stability_secondary_np;
                static_stability_agreement_col(k) = static_info.static_stability_agreement;

                if ~static_info.static_stability_agreement ...
                        && ~strcmp(static_info.static_stability_primary, 'undefined') ...
                        && ~strcmp(static_info.static_stability_secondary_np, 'undefined')
                    case_warnings{end+1} = sprintf( ...
                        ['Static stability methods disagree: primary ', ...
                         'Cm_alpha/dCm_dCL method = %s, secondary ', ...
                         'neutral-point method = %s.'], ...
                        static_info.static_stability_primary, ...
                        static_info.static_stability_secondary_np); %#ok<AGROW>
                end

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

baseline_index = local_find_sweep_baseline_index(sweep, parameter_key);
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
    parameter_value_col, ...
    u0_kt_col, ...
    factor_col, ...
    mach_col, ...
    xcg_cg_mac_col, ...
    xcg_delta_mac_col, ...
    xcg_xcg_ft_col, ...
    xcg_lt_ft_col, ...
    xcg_VH_col, ...
    cm_alpha_col, ...
    dcm_dcl_col, ...
    static_margin_np_col, ...
    static_margin_cmalpha_col, ...
    x_np_mac_col, ...
    x_np_from_cmalpha_mac_col, ...
    static_stability_primary_col, ...
    static_stability_primary_method_col, ...
    static_stability_secondary_np_col, ...
    static_stability_agreement_col, ...
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
        'ParameterValue', ...
        'u0_kt', ...
        'SweepFactor', ...
        'Mach', ...
        'cg_mac', ...
        'Delta_cg_mac', ...
        'x_cg_ft', ...
        'lt_ft', ...
        'V_H', ...
        'Cm_alpha', ...
        'dCm_dCL', ...
        'StaticMargin_NP', ...
        'StaticMargin_CmAlpha', ...
        'x_NP_mac', ...
        'x_NP_from_CmAlpha_mac', ...
        'StaticStability_Primary', ...
        'StaticStability_PrimaryMethod', ...
        'StaticStability_Secondary_NP', ...
        'StaticStability_MethodAgreement', ...
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

if any(strcmp(parameter_key, {'x_cg','xcg','cg_mac','cgmac'}))
    param_out.static_stability = struct();
    param_out.static_stability.critical_cg_mac_from_neutral_point = ...
        local_estimate_zero_crossing(xcg_cg_mac_col, static_margin_np_col);
    param_out.static_stability.critical_cg_mac_from_Cm_alpha = ...
        local_estimate_zero_crossing(xcg_cg_mac_col, static_margin_cmalpha_col);
    param_out.static_stability.critical_cg_mac_from_Cm_alpha_direct = ...
        local_estimate_zero_crossing(xcg_cg_mac_col, cm_alpha_col);
    param_out.static_stability.primary_method = 'Cm_alpha / dCm_dCL';
    param_out.static_stability.secondary_method = 'neutral-point static margin';
    param_out.static_stability.notes = [ ...
        'Critical CG estimates are interpolated from the accepted sweep ', ...
        'points when a zero crossing is present. The primary static-stability ', ...
        'method is Cm_alpha/dCm_dCL. The neutral-point static margin is kept ', ...
        'as a secondary method and disagreements are flagged in the summary ', ...
        'table and warnings. NaN means no crossing was found inside the ', ...
        'accepted sweep range.'];
end

end

function [long_out, long_pSI] = local_run_longitudinal_core(long_pAV)
long_pSI = AVS_to_SI(long_pAV);
long_out = SI_longitudinal_analysis_grouped(long_pSI);
end

function static_info = local_extract_longitudinal_static_info(long_out)
static_info = struct();
static_info.Cm_alpha = NaN;
static_info.dCm_dCL = NaN;
static_info.static_margin_from_neutral_point = NaN;
static_info.static_margin_from_Cm_alpha = NaN;
static_info.x_NP_by_c = NaN;
static_info.x_NP_by_c_from_Cm_alpha = NaN;
static_info.static_stability_primary_method = 'Cm_alpha / dCm_dCL';
static_info.static_stability_secondary_method = 'neutral-point static margin';
static_info.static_stability_primary = 'undefined';
static_info.static_stability_secondary_np = 'undefined';
static_info.static_stability_agreement = false;
static_info.static_stability = 'undefined';

if ~isstruct(long_out)
    return;
end

if isfield(long_out, 'static_stability') && isstruct(long_out.static_stability)
    ss = long_out.static_stability;
    static_info.Cm_alpha = local_get_numeric_field(ss, 'Cm_alpha');
    static_info.dCm_dCL = local_get_numeric_field(ss, 'dCm_dCL');
    static_info.static_margin_from_neutral_point = local_get_numeric_field(ss, 'static_margin_from_neutral_point');
    static_info.static_margin_from_Cm_alpha = local_get_numeric_field(ss, 'static_margin_from_Cm_alpha');
    static_info.x_NP_by_c = local_get_numeric_field(ss, 'x_NP_by_c');
    static_info.x_NP_by_c_from_Cm_alpha = local_get_numeric_field(ss, 'x_NP_by_c_from_Cm_alpha');
end

if ~isfinite(static_info.Cm_alpha)
    static_info.Cm_alpha = local_get_numeric_field(long_out, 'Cm_alpha');
end
if ~isfinite(static_info.dCm_dCL)
    static_info.dCm_dCL = local_get_numeric_field(long_out, 'dCm_dCL');
end
if ~isfinite(static_info.static_margin_from_neutral_point)
    static_info.static_margin_from_neutral_point = local_get_numeric_field(long_out, 'static_margin_from_neutral_point');
end
if ~isfinite(static_info.static_margin_from_Cm_alpha)
    static_info.static_margin_from_Cm_alpha = local_get_numeric_field(long_out, 'static_margin_from_Cm_alpha');
end

static_info.static_stability_primary = local_static_stability_label_from_derivative( ...
    static_info.dCm_dCL, static_info.Cm_alpha);

static_info.static_stability_secondary_np = local_static_stability_label_from_margin( ...
    static_info.static_margin_from_neutral_point);

static_info.static_stability_agreement = strcmp( ...
    static_info.static_stability_primary, ...
    static_info.static_stability_secondary_np);

% Backward-compatible field: use the primary method.
static_info.static_stability = static_info.static_stability_primary;
end

function label = local_static_stability_label_from_derivative(dCm_dCL, Cm_alpha)
tol = 1.0e-8;

if isfinite(dCm_dCL)
    metric = dCm_dCL;
elseif isfinite(Cm_alpha)
    metric = Cm_alpha;
else
    label = 'undefined';
    return;
end

if metric < -tol
    label = 'stable';
elseif metric > tol
    label = 'unstable';
else
    label = 'neutral';
end
end

function label = local_static_stability_label_from_margin(static_margin)
tol = 1.0e-8;

if ~isfinite(static_margin)
    label = 'undefined';
elseif static_margin > tol
    label = 'stable';
elseif static_margin < -tol
    label = 'unstable';
else
    label = 'neutral';
end
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

function branch = local_default_analysis_branch(parameter_key)
if any(strcmp(parameter_key, {'x_cg','xcg','cg_mac','cgmac'}))
    branch = 'longitudinal';
else
    branch = 'both';
end
end

function idx = local_find_sweep_baseline_index(sweep, parameter_key)
idx = NaN;
if any(strcmp(parameter_key, {'u_0','u0'}))
    if isfield(sweep, 'accepted_u0_kt') && isfield(sweep, 'baseline_u0_kt')
        idx = local_find_baseline_index(sweep.accepted_u0_kt, sweep.baseline_u0_kt);
    end
elseif any(strcmp(parameter_key, {'x_cg','xcg','cg_mac','cgmac'}))
    if isfield(sweep, 'accepted_cg_mac') && isfield(sweep, 'baseline_cg_mac')
        idx = local_find_baseline_index(sweep.accepted_cg_mac, sweep.baseline_cg_mac);
    end
end
end

function critical_x = local_estimate_zero_crossing(x, y)
critical_x = NaN;
if ~isnumeric(x) || ~isnumeric(y) || isempty(x) || isempty(y)
    return;
end
x = x(:);
y = y(:);
valid = isfinite(x) & isfinite(y);
x = x(valid);
y = y(valid);
if numel(x) < 2
    return;
end

[~, ord] = sort(x);
x = x(ord);
y = y(ord);

tol = 1.0e-10;
exact_idx = find(abs(y) <= tol, 1, 'first');
if ~isempty(exact_idx)
    critical_x = x(exact_idx);
    return;
end

for k = 1:(numel(x)-1)
    if y(k) == y(k+1)
        continue;
    end
    if y(k) * y(k+1) < 0
        critical_x = x(k) - y(k) * (x(k+1) - x(k)) / (y(k+1) - y(k));
        return;
    end
end
end

function value = local_get_numeric_field(s, field_name)
value = NaN;
if isstruct(s) && isfield(s, field_name) && isnumeric(s.(field_name)) && isscalar(s.(field_name))
    value = s.(field_name);
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
