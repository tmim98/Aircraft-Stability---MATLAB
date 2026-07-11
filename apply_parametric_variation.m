function [long_pAV_var, lat_pAV_var, info] = apply_parametric_variation(long_pAV_base, lat_pAV_base, parameter_name, parameter_value, options)
% APPLY_PARAMETRIC_VARIATION Apply one parametric variation to AVS input copies.
%
%   [long_pAV_var, lat_pAV_var, info] = apply_parametric_variation( ...
%       long_pAV_base, lat_pAV_base, parameter_name, parameter_value)
%
% Current implemented parameter
%   parameter_name = 'u_0'
%
% For u_0
%   parameter_value is the new u_0 value in knots.
%
% Policy implemented
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
    otherwise
        error('apply_parametric_variation:UnsupportedParameter', ...
            'Unsupported parametric parameter: %s', parameter_name);
end

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
