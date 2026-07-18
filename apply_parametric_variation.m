function [long_pAV_var, lat_pAV_var, info] = apply_parametric_variation(long_pAV_base, lat_pAV_base, parameter_name, parameter_value, options)
% APPLY_PARAMETRIC_VARIATION Apply one parametric variation to AVS input copies.
%
%   [long_pAV_var, lat_pAV_var, info] = apply_parametric_variation( ...
%       long_pAV_base, lat_pAV_base, parameter_name, parameter_value)
%
% Implemented parameters
%   parameter_name = 'u_0'
%       parameter_value is the new u_0 value in knots.
%
%   parameter_name = 'x_cg'
%       parameter_value is the new cg_mac = x_cg/c_bar value.
%
% u_0 policy
%   - Update u_0 in the longitudinal and lateral AVS input copies.
%   - Keep rho fixed.
%   - Keep S fixed.
%   - Keep mass/weight fixed.
%   - Recompute dynamic pressure from qbar = 0.5*rho*u0^2.
%   - Recompute CL0 using baseline-preserving trim scaling:
%         CL0_new = CL0_baseline * (qbar_baseline/qbar_new)
%   - Update active lateral lift-coefficient aliases:
%         pAV.CL0
%         pAV.CL
%   - Recompute M0 where the field exists.
%   - Recompute C_Lu, C_Du, and C_m_u from CL_M, CD_M, and Cm_M when the
%     source fields exist.
%
% x_cg policy
%   - Sweep cg_mac = x_cg/c_bar.
%   - Update x_cg_ft / x_cg and cg_mac aliases.
%   - Preserve the baseline horizontal-tail reference station by default:
%         x_tail_ref = x_cg_baseline + lt_baseline
%         lt_new     = x_tail_ref - x_cg_new
%   - Recompute V_H from the updated lt.
%   - Update Cm_alpha with a baseline-preserving incremental relation:
%         Cm_alpha_new = Cm_alpha_base
%             + CL_alpha_w*((x_cg_new - x_cg_base)/c_bar)
%             - eta*(V_H_new - V_H_base)*CL_alpha_t*(1 - dEdalpha)
%
% This helper does not run any analysis core and does not modify files.

if nargin < 5 || isempty(options)
    options = struct();
end

if nargin < 4
    error('apply_parametric_variation:NotEnoughInputs', ...
        'Provide baseline structs, parameter name, and parameter value.');
end

parameter_key = lower(strtrim(parameter_name));
parameter_key = strrep(parameter_key, ' ', '');
parameter_key = strrep(parameter_key, '-', '_');

switch parameter_key
    case {'u_0', 'u0'}
        [long_pAV_var, lat_pAV_var, info] = local_apply_u0_variation( ...
            long_pAV_base, lat_pAV_base, parameter_value, options);

    case {'x_cg', 'xcg', 'cg_mac', 'cgmac'}
        [long_pAV_var, lat_pAV_var, info] = local_apply_xcg_variation( ...
            long_pAV_base, lat_pAV_base, parameter_value, options);

    otherwise
        error('apply_parametric_variation:UnsupportedParameter', ...
            'Unsupported parametric parameter: %s', parameter_name);
end

end

function [long_var, lat_var, info] = local_apply_xcg_variation(long_base, lat_base, new_cg_mac, options)
tol = local_get_option(options, 'tolerance', 1.0e-10);
cg_min = local_get_option(options, 'cg_mac_min', 0.05);
cg_max = local_get_option(options, 'cg_mac_max', 0.60);
freeze_tail_arm = local_get_option(options, 'freeze_tail_arm', false);

if ~isnumeric(new_cg_mac) || ~isscalar(new_cg_mac) || ~isfinite(new_cg_mac)
    error('apply_parametric_variation:InvalidXcg', ...
        'The x_cg parameter value must be a finite scalar cg_mac value.');
end

if new_cg_mac < cg_min - tol || new_cg_mac > cg_max + tol
    error('apply_parametric_variation:XcgSafetyLimitExceeded', ...
        'Requested cg_mac = %.6g is outside the safety limits %.3f <= cg_mac <= %.3f.', ...
        new_cg_mac, cg_min, cg_max);
end

warnings = {};

c_bar_ft = local_first_finite([ ...
    local_get_cbar_ft(long_base), ...
    local_get_cbar_ft(lat_base)]);

if ~isfinite(c_bar_ft) || c_bar_ft <= 0
    error('apply_parametric_variation:MissingCbar', ...
        'Could not determine a positive c_bar value in feet for x_cg variation.');
end

baseline_x_cg_ft = local_first_finite([ ...
    local_get_xcg_ft(long_base, c_bar_ft), ...
    local_get_xcg_ft(lat_base, c_bar_ft)]);

if ~isfinite(baseline_x_cg_ft)
    error('apply_parametric_variation:MissingBaselineXcg', ...
        'Could not determine baseline x_cg in feet.');
end

baseline_cg_mac = baseline_x_cg_ft / c_bar_ft;
new_x_cg_ft = new_cg_mac * c_bar_ft;

baseline_lt_ft = local_first_finite([ ...
    local_get_tail_arm_ft(long_base), ...
    local_get_tail_arm_ft(lat_base)]);

if ~isfinite(baseline_lt_ft) || baseline_lt_ft <= 0
    error('apply_parametric_variation:MissingTailArm', ...
        'Could not determine a positive baseline horizontal-tail arm in feet.');
end

baseline_tail_ref_station_ft = baseline_x_cg_ft + baseline_lt_ft;

if freeze_tail_arm
    new_lt_ft = baseline_lt_ft;
    tail_arm_policy = 'freeze_tail_arm';
else
    new_lt_ft = baseline_tail_ref_station_ft - new_x_cg_ft;
    tail_arm_policy = 'preserve_tail_reference_station';
end

if ~isfinite(new_lt_ft) || new_lt_ft <= 0
    error('apply_parametric_variation:InvalidTailArm', ...
        'Updated horizontal-tail arm lt = %.6g ft is not positive.', new_lt_ft);
end

S_ft2 = local_first_finite([ ...
    local_get_area_ft2(long_base, 'S_ft2', 'S'), ...
    local_get_area_ft2(lat_base, 'S_ft2', 'S')]);

St_ft2 = local_first_finite([ ...
    local_get_area_ft2(long_base, 'St_ft2', 'St'), ...
    local_get_area_ft2(lat_base, 'St_ft2', 'St')]);

baseline_V_H = local_compute_tail_volume_ratio(baseline_lt_ft, St_ft2, S_ft2, c_bar_ft);
new_V_H = local_compute_tail_volume_ratio(new_lt_ft, St_ft2, S_ft2, c_bar_ft);

baseline_Cm_alpha = local_first_finite([ ...
    local_get_numeric_field(long_base, 'Cm_alpha'), ...
    local_get_numeric_field(lat_base, 'Cm_alpha')]);

if ~isfinite(baseline_Cm_alpha)
    error('apply_parametric_variation:MissingCmAlpha', ...
        'Could not determine baseline Cm_alpha for x_cg variation.');
end

CL_alpha_w = local_first_finite([ ...
    local_get_numeric_field(long_base, 'CL_alpha_w'), ...
    local_get_numeric_field(lat_base, 'CL_alpha_w')]);

CL_alpha_t = local_first_finite([ ...
    local_get_numeric_field(long_base, 'CL_alpha_t'), ...
    local_get_numeric_field(lat_base, 'CL_alpha_t')]);

eta = local_first_finite([ ...
    local_get_numeric_field(long_base, 'eta'), ...
    local_get_numeric_field(lat_base, 'eta')]);
if ~isfinite(eta)
    eta = 1.0;
    warnings{end+1} = 'eta was missing; x_cg Cm_alpha update used eta = 1.0.'; %#ok<AGROW>
end

dEdalpha = local_first_finite([ ...
    local_get_numeric_field(long_base, 'dEdalpha'), ...
    local_get_numeric_field(lat_base, 'dEdalpha')]);
if ~isfinite(dEdalpha)
    dEdalpha = 0.0;
    warnings{end+1} = 'dEdalpha was missing; x_cg Cm_alpha update used dEdalpha = 0.0.'; %#ok<AGROW>
end

if ~isfinite(CL_alpha_w)
    error('apply_parametric_variation:MissingCLalphaW', ...
        'Could not determine CL_alpha_w for x_cg Cm_alpha update.');
end

cg_increment_Cm_alpha = CL_alpha_w * ((new_x_cg_ft - baseline_x_cg_ft) / c_bar_ft);

tail_increment_Cm_alpha = 0.0;
if isfinite(new_V_H) && isfinite(baseline_V_H) && isfinite(CL_alpha_t)
    tail_increment_Cm_alpha = -eta * (new_V_H - baseline_V_H) * CL_alpha_t * (1.0 - dEdalpha);
else
    warnings{end+1} = ...
        'Tail-volume contribution to Cm_alpha was not updated because V_H or CL_alpha_t could not be determined.'; %#ok<AGROW>
end

new_Cm_alpha = baseline_Cm_alpha + cg_increment_Cm_alpha + tail_increment_Cm_alpha;

long_var = long_base;
lat_var = lat_base;

long_var = local_update_xcg_aliases(long_var, new_x_cg_ft, new_cg_mac, new_lt_ft);
lat_var  = local_update_xcg_aliases(lat_var,  new_x_cg_ft, new_cg_mac, new_lt_ft);

long_var.Cm_alpha = new_Cm_alpha;
if isfield(lat_var, 'Cm_alpha')
    lat_var.Cm_alpha = new_Cm_alpha;
end

info = struct();
info.parameter_name = 'x_cg';
info.parameter_value_cg_mac = new_cg_mac;
info.parameter_value_x_cg_ft = new_x_cg_ft;
info.baseline_cg_mac = baseline_cg_mac;
info.baseline_x_cg_ft = baseline_x_cg_ft;
info.baseline_c_bar_ft = c_bar_ft;
info.cg_mac_min = cg_min;
info.cg_mac_max = cg_max;
info.tail_arm_policy = tail_arm_policy;
info.baseline_tail_ref_station_ft = baseline_tail_ref_station_ft;
info.new_tail_ref_station_ft = new_x_cg_ft + new_lt_ft;
info.baseline_lt_ft = baseline_lt_ft;
info.new_lt_ft = new_lt_ft;
info.baseline_V_H = baseline_V_H;
info.new_V_H = new_V_H;
info.baseline_Cm_alpha = baseline_Cm_alpha;
info.new_Cm_alpha = new_Cm_alpha;
info.cg_increment_Cm_alpha = cg_increment_Cm_alpha;
info.tail_increment_Cm_alpha = tail_increment_Cm_alpha;
info.CL_alpha_w_used = CL_alpha_w;
info.CL_alpha_t_used = CL_alpha_t;
info.eta_used = eta;
info.dEdalpha_used = dEdalpha;
info.warnings = warnings;

end

function [long_var, lat_var, info] = local_apply_u0_variation(long_base, lat_base, new_u0_kt, options)
KT2FTPS = 1.6878098571011957;

tol = local_get_option(options, 'tolerance', 1.0e-10);
mach_cap = local_get_option(options, 'mach_cap', 0.90);

if ~isnumeric(new_u0_kt) || ~isscalar(new_u0_kt) || ~isfinite(new_u0_kt) || new_u0_kt <= 0
    error('apply_parametric_variation:InvalidU0', ...
        'The u_0 parameter value must be a positive finite scalar in knots.');
end

warnings = {};

baseline_u0_kt = local_first_finite([ ...
    local_get_u0_knots(long_base), ...
    local_get_u0_knots(lat_base)]);

if ~isfinite(baseline_u0_kt) || baseline_u0_kt <= 0
    error('apply_parametric_variation:MissingBaselineU0', ...
        'Could not determine a positive baseline u_0 in knots.');
end

speed_of_sound_kt = local_get_option(options, 'speed_of_sound_kt', NaN);
if ~isfinite(speed_of_sound_kt)
    baseline_mach = local_first_finite([ ...
        local_get_numeric_field(long_base, 'M0'), ...
        local_get_numeric_field(lat_base, 'M0')]);
    if isfinite(baseline_mach) && baseline_mach > 0
        speed_of_sound_kt = baseline_u0_kt / baseline_mach;
    else
        error('apply_parametric_variation:MissingMachSource', ...
            ['Could not determine speed of sound for the u_0 Mach cap. ', ...
             'Provide options.speed_of_sound_kt or a positive baseline M0.']);
    end
end

new_mach = new_u0_kt / speed_of_sound_kt;
if new_mach > mach_cap + tol
    error('apply_parametric_variation:MachCapExceeded', ...
        'Requested u_0 = %.6g knots gives M = %.6g, above the Mach %.3f cap.', ...
        new_u0_kt, new_mach, mach_cap);
end

long_var = long_base;
lat_var = lat_base;

long_info = local_update_one_u0_struct(long_base, new_u0_kt, new_mach, KT2FTPS, 'longitudinal');
lat_info  = local_update_one_u0_struct(lat_base,  new_u0_kt, new_mach, KT2FTPS, 'lateral_directional');

long_var = long_info.pAV;
lat_var = lat_info.pAV;

warnings = [warnings, long_info.warnings, lat_info.warnings]; %#ok<AGROW>

info = struct();
info.parameter_name = 'u_0';
info.parameter_value_kt = new_u0_kt;
info.baseline_u0_kt = baseline_u0_kt;
info.speed_of_sound_kt = speed_of_sound_kt;
info.mach = new_mach;
info.mach_cap = mach_cap;
info.longitudinal = rmfield(long_info, 'pAV');
info.lateral_directional = rmfield(lat_info, 'pAV');
info.warnings = warnings;

end

function branch_info = local_update_one_u0_struct(pAV_in, new_u0_kt, new_mach, KT2FTPS, branch_name)
pAV = pAV_in;
warnings = {};

baseline_u0_kt = local_get_u0_knots(pAV_in);
baseline_qbar_psf = local_compute_qbar_psf(pAV_in, baseline_u0_kt, KT2FTPS);
new_qbar_psf = local_compute_qbar_psf(pAV_in, new_u0_kt, KT2FTPS);

baseline_CL0 = local_get_numeric_field(pAV_in, 'CL0');
new_CL0 = NaN;

if isfinite(baseline_CL0) && isfinite(baseline_qbar_psf) && isfinite(new_qbar_psf) && new_qbar_psf > 0
    new_CL0 = baseline_CL0 * (baseline_qbar_psf / new_qbar_psf);
else
    warnings{end+1} = sprintf( ...
        '%s: CL0 was not updated because baseline CL0 or qbar could not be determined.', branch_name); %#ok<AGROW>
end

% Update speed fields that already exist.
if isfield(pAV, 'u0_kt')
    pAV.u0_kt = new_u0_kt;
end
if isfield(pAV, 'u0')
    % In the current AVS input files, pAV.u0 is stored in knots.
    pAV.u0 = new_u0_kt;
end

% Update Mach field only when it already exists.
if isfield(pAV, 'M0')
    pAV.M0 = new_mach;
end

% Store updated CL0 and active lateral alias when the fields already exist.
if isfinite(new_CL0)
    if isfield(pAV, 'CL0')
        pAV.CL0 = new_CL0;
    end
    if isfield(pAV, 'CL')
        pAV.CL = new_CL0;
    end
end

% Update qbar field only when a stored qbar field already exists.
if isfield(pAV, 'qbar_psf')
    pAV.qbar_psf = new_qbar_psf;
end
if isfield(pAV, 'Q_psf')
    pAV.Q_psf = new_qbar_psf;
end

% Recompute Mach-derived speed derivatives when source fields exist.
if isfield(pAV, 'CL_M') && isnumeric(pAV.CL_M) && isscalar(pAV.CL_M) && isfinite(pAV.CL_M)
    pAV.C_Lu = new_mach * pAV.CL_M;
end
if isfield(pAV, 'CD_M') && isnumeric(pAV.CD_M) && isscalar(pAV.CD_M) && isfinite(pAV.CD_M)
    pAV.C_Du = new_mach * pAV.CD_M;
end
if isfield(pAV, 'Cm_M') && isnumeric(pAV.Cm_M) && isscalar(pAV.Cm_M) && isfinite(pAV.Cm_M)
    pAV.C_m_u = new_mach * pAV.Cm_M;
end

branch_info = struct();
branch_info.pAV = pAV;
branch_info.branch = branch_name;
branch_info.baseline_u0_kt = baseline_u0_kt;
branch_info.new_u0_kt = new_u0_kt;
branch_info.baseline_qbar_psf = baseline_qbar_psf;
branch_info.new_qbar_psf = new_qbar_psf;
branch_info.baseline_CL0 = baseline_CL0;
branch_info.new_CL0 = new_CL0;
branch_info.warnings = warnings;

end

function pAV = local_update_xcg_aliases(pAV, new_x_cg_ft, new_cg_mac, new_lt_ft)
if isfield(pAV, 'x_cg_ft')
    pAV.x_cg_ft = new_x_cg_ft;
end

if isfield(pAV, 'x_cg')
    pAV.x_cg = new_x_cg_ft;
end

% Store cg_mac explicitly. This is harmless for the current converter/core
% and gives later sweep/export code a clean normalized CG reference.
pAV.cg_mac = new_cg_mac;

if isfield(pAV, 'lt_ft')
    pAV.lt_ft = new_lt_ft;
end

if isfield(pAV, 'lt')
    pAV.lt = new_lt_ft;
end

end

function V_H = local_compute_tail_volume_ratio(lt_ft, St_ft2, S_ft2, c_bar_ft)
if isfinite(lt_ft) && isfinite(St_ft2) && isfinite(S_ft2) && isfinite(c_bar_ft) ...
        && S_ft2 > 0 && c_bar_ft > 0
    V_H = lt_ft * St_ft2 / (S_ft2 * c_bar_ft);
else
    V_H = NaN;
end
end

function qbar_psf = local_compute_qbar_psf(pAV, u0_kt, KT2FTPS)
rho = local_first_finite([ ...
    local_get_numeric_field(pAV, 'rho_slugft3'), ...
    local_get_numeric_field(pAV, 'rho')]);

if ~isfinite(rho) || ~isfinite(u0_kt) || u0_kt <= 0
    qbar_psf = NaN;
    return;
end

u0_fps = u0_kt * KT2FTPS;
qbar_psf = 0.5 * rho * u0_fps^2;
end

function value = local_get_option(options, field_name, default_value)
if isstruct(options) && isfield(options, field_name) && ~isempty(options.(field_name))
    value = options.(field_name);
else
    value = default_value;
end
end

function u0_kt = local_get_u0_knots(pAV)
u0_kt = NaN;
if ~isstruct(pAV)
    return;
end

if isfield(pAV, 'u0_kt') && isnumeric(pAV.u0_kt) && isscalar(pAV.u0_kt)
    u0_kt = pAV.u0_kt;
elseif isfield(pAV, 'u0') && isnumeric(pAV.u0) && isscalar(pAV.u0)
    % In the current AVS input files, pAV.u0 is stored in knots.
    u0_kt = pAV.u0;
end
end

function c_bar_ft = local_get_cbar_ft(pAV)
c_bar_ft = local_first_finite([ ...
    local_get_numeric_field(pAV, 'c_bar_ft'), ...
    local_get_numeric_field(pAV, 'c_bar')]);
end

function x_cg_ft = local_get_xcg_ft(pAV, c_bar_ft)
x_cg_ft = local_first_finite([ ...
    local_get_numeric_field(pAV, 'x_cg_ft'), ...
    local_get_numeric_field(pAV, 'x_cg')]);

if ~isfinite(x_cg_ft)
    cg_mac = local_get_numeric_field(pAV, 'cg_mac');
    if isfinite(cg_mac) && isfinite(c_bar_ft)
        x_cg_ft = cg_mac * c_bar_ft;
    end
end
end

function lt_ft = local_get_tail_arm_ft(pAV)
lt_ft = local_first_finite([ ...
    local_get_numeric_field(pAV, 'lt_ft'), ...
    local_get_numeric_field(pAV, 'lt')]);
end

function area_ft2 = local_get_area_ft2(pAV, field_name_1, field_name_2)
area_ft2 = local_first_finite([ ...
    local_get_numeric_field(pAV, field_name_1), ...
    local_get_numeric_field(pAV, field_name_2)]);
end

function value = local_get_numeric_field(s, field_name)
value = NaN;
if isstruct(s) && isfield(s, field_name) && isnumeric(s.(field_name)) && isscalar(s.(field_name))
    value = s.(field_name);
end
end

function value = local_first_finite(values)
value = NaN;
for k = 1:numel(values)
    if isfinite(values(k))
        value = values(k);
        return;
    end
end
end
