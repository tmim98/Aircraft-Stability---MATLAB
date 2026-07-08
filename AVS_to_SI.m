function p = AVS_to_SI(pAV)
%AVS_TO_SI Convert aviation-standard inputs into SI fields expected by the
%longitudinal SI core.
%
% The existing longitudinal core expects SI quantities. This wrapper accepts
% the current AVS input style and converts only dimensional quantities.
%
% Supported input styles:
%   Explicit AVS field names:
%       rho_slugft3, u0_kt, S_ft2, St_ft2, c_bar_ft, lt_ft,
%       x_cg_ft, x_ac_ft, W_lbf, m_slug, Iyy_slugft2
%
%   Generic AVS field names when input_unit_system / units is 'AVS':
%       rho, u0, S, St, c_bar, lt, x_cg, x_ac, W, Iy, Iyy
%
%   Generic SI field names when input_unit_system / units is not 'AVS':
%       rho, u0, S, St, c_bar, lt, x_cg, x_ac, m, Iy, Iyy
%
% Dimensionless aerodynamic coefficients and radian angles are copied
% without unit conversion.

g0 = 9.80665;  % SI gravity used internally in the longitudinal core

is_avs_input = local_is_avs_input(pAV);

p = struct();

% ================= DENSITY =================
if isfield(pAV, 'rho_slugft3')
    p.rho = aircraft_unit_convert(pAV.rho_slugft3, 'slugft3_to_kgm3');

elseif isfield(pAV, 'rho') && is_avs_input
    p.rho = aircraft_unit_convert(pAV.rho, 'slugft3_to_kgm3');

elseif isfield(pAV, 'rho')
    p.rho = pAV.rho;  % assume SI kg/m^3 only when input is not AVS

else
    error('AVS_to_SI:MissingDensity', ...
        'Provide pAV.rho_slugft3, or pAV.rho with pAV.units/input_unit_system set correctly.');
end

% ================= SPEED =================
if isfield(pAV, 'u0_kt')
    p.u0 = aircraft_unit_convert(pAV.u0_kt, 'kt_to_mps');

elseif isfield(pAV, 'u0') && is_avs_input
    p.u0 = aircraft_unit_convert(pAV.u0, 'kt_to_mps');

elseif isfield(pAV, 'u0')
    p.u0 = pAV.u0;  % assume SI m/s only when input is not AVS

else
    error('AVS_to_SI:MissingSpeed', ...
        'Provide pAV.u0_kt, or pAV.u0 with pAV.units/input_unit_system set correctly.');
end

% ================= GEOMETRY =================
% Preferred explicit AVS field names:
%   pAV.S_ft2     = wing reference area, ft^2
%   pAV.St_ft2    = horizontal-tail reference area, ft^2
%   pAV.c_bar_ft  = mean aerodynamic chord, ft
%   pAV.lt_ft     = distance from c.g. to horizontal-tail reference point, ft
%   pAV.x_cg_ft   = center-of-gravity station, ft
%   pAV.x_ac_ft   = aerodynamic-center station, ft
%
% Generic AVS fallback names are accepted only when input is declared AVS:
%   pAV.S, pAV.St, pAV.c_bar, pAV.lt, pAV.x_cg, pAV.x_ac

if isfield(pAV, 'S_ft2')
    p.S = aircraft_unit_convert(pAV.S_ft2, 'ft2_to_m2');

elseif isfield(pAV, 'S') && is_avs_input
    p.S = aircraft_unit_convert(pAV.S, 'ft2_to_m2');

elseif isfield(pAV, 'S')
    p.S = pAV.S;  % assume SI m^2 only when input is not AVS

else
    error('AVS_to_SI:MissingWingArea', ...
        'Provide pAV.S_ft2, or pAV.S with pAV.units/input_unit_system set correctly.');
end

if isfield(pAV, 'St_ft2')
    p.St = aircraft_unit_convert(pAV.St_ft2, 'ft2_to_m2');

elseif isfield(pAV, 'St') && is_avs_input
    p.St = aircraft_unit_convert(pAV.St, 'ft2_to_m2');

elseif isfield(pAV, 'St')
    p.St = pAV.St;  % assume SI m^2 only when input is not AVS

else
    error('AVS_to_SI:MissingTailArea', ...
        'Provide pAV.St_ft2, or pAV.St with pAV.units/input_unit_system set correctly.');
end

if isfield(pAV, 'c_bar_ft')
    p.c_bar = aircraft_unit_convert(pAV.c_bar_ft, 'ft_to_m');

elseif isfield(pAV, 'c_bar') && is_avs_input
    p.c_bar = aircraft_unit_convert(pAV.c_bar, 'ft_to_m');

elseif isfield(pAV, 'c_bar')
    p.c_bar = pAV.c_bar;  % assume SI m only when input is not AVS

else
    error('AVS_to_SI:MissingMeanChord', ...
        'Provide pAV.c_bar_ft, or pAV.c_bar with pAV.units/input_unit_system set correctly.');
end

if isfield(pAV, 'lt_ft')
    p.lt = aircraft_unit_convert(pAV.lt_ft, 'ft_to_m');

elseif isfield(pAV, 'lt') && is_avs_input
    p.lt = aircraft_unit_convert(pAV.lt, 'ft_to_m');

elseif isfield(pAV, 'lt')
    p.lt = pAV.lt;  % assume SI m only when input is not AVS

else
    error('AVS_to_SI:MissingTailArm', ...
        'Provide pAV.lt_ft, or pAV.lt with pAV.units/input_unit_system set correctly.');
end

if isfield(pAV, 'x_cg_ft')
    p.x_cg = aircraft_unit_convert(pAV.x_cg_ft, 'ft_to_m');

elseif isfield(pAV, 'x_cg') && is_avs_input
    p.x_cg = aircraft_unit_convert(pAV.x_cg, 'ft_to_m');

elseif isfield(pAV, 'x_cg')
    p.x_cg = pAV.x_cg;  % assume SI m only when input is not AVS

else
    error('AVS_to_SI:MissingCG', ...
        'Provide pAV.x_cg_ft, or pAV.x_cg with pAV.units/input_unit_system set correctly.');
end

if isfield(pAV, 'x_ac_ft')
    p.x_ac = aircraft_unit_convert(pAV.x_ac_ft, 'ft_to_m');

elseif isfield(pAV, 'x_ac') && is_avs_input
    p.x_ac = aircraft_unit_convert(pAV.x_ac, 'ft_to_m');

elseif isfield(pAV, 'x_ac')
    p.x_ac = pAV.x_ac;  % assume SI m only when input is not AVS

else
    error('AVS_to_SI:MissingAC', ...
        'Provide pAV.x_ac_ft, or pAV.x_ac with pAV.units/input_unit_system set correctly.');
end

% ================= MASS / WEIGHT =================
% Preferred explicit AVS field names:
%   pAV.W_lbf  = aircraft weight, lbf
%   pAV.m_slug = aircraft mass, slugs
%
% Generic AVS fallback:
%   pAV.W = aircraft weight, lbf
%
% Non-AVS fallback:
%   pAV.m = aircraft mass, kg

if isfield(pAV, 'W_lbf') && ~isempty(pAV.W_lbf) && ~isnan(pAV.W_lbf)
    W_N = aircraft_unit_convert(pAV.W_lbf, 'lbf_to_n');
    p.m = W_N / g0;

elseif isfield(pAV, 'm_slug') && ~isempty(pAV.m_slug) && ~isnan(pAV.m_slug)
    p.m = aircraft_unit_convert(pAV.m_slug, 'slug_to_kg');

elseif isfield(pAV, 'W') && is_avs_input && ~isempty(pAV.W) && ~isnan(pAV.W)
    W_N = aircraft_unit_convert(pAV.W, 'lbf_to_n');
    p.m = W_N / g0;

elseif isfield(pAV, 'm') && ~is_avs_input && ~isempty(pAV.m) && ~isnan(pAV.m)
    p.m = pAV.m;  % assume SI kg only when input is not AVS

else
    error('AVS_to_SI:MissingMass', ...
        ['Provide pAV.W_lbf, pAV.m_slug, pAV.W with input declared ', ...
         'as AVS, or pAV.m with input declared as SI.']);
end

% ================= PITCH INERTIA =================
% Preferred explicit AVS field:
%   pAV.Iyy_slugft2 = pitch moment of inertia, slug*ft^2
%
% Generic AVS fallback:
%   pAV.Iy or pAV.Iyy = pitch moment of inertia, slug*ft^2
%
% Non-AVS fallback:
%   pAV.Iyy or pAV.Iy = pitch moment of inertia, kg*m^2

if isfield(pAV, 'Iyy_slugft2') && ~isempty(pAV.Iyy_slugft2) && ~isnan(pAV.Iyy_slugft2)
    p.Iyy = aircraft_unit_convert(pAV.Iyy_slugft2, 'slugft2_to_kgm2');

elseif isfield(pAV, 'Iy') && is_avs_input && ~isempty(pAV.Iy) && ~isnan(pAV.Iy)
    p.Iyy = aircraft_unit_convert(pAV.Iy, 'slugft2_to_kgm2');

elseif isfield(pAV, 'Iyy') && is_avs_input && ~isempty(pAV.Iyy) && ~isnan(pAV.Iyy)
    p.Iyy = aircraft_unit_convert(pAV.Iyy, 'slugft2_to_kgm2');

elseif isfield(pAV, 'Iyy') && ~is_avs_input && ~isempty(pAV.Iyy) && ~isnan(pAV.Iyy)
    p.Iyy = pAV.Iyy;  % assume SI kg*m^2 only when input is not AVS

elseif isfield(pAV, 'Iy') && ~is_avs_input && ~isempty(pAV.Iy) && ~isnan(pAV.Iy)
    p.Iyy = pAV.Iy;   % assume SI kg*m^2 only when input is not AVS

else
    error('AVS_to_SI:MissingInertia', ...
        ['Provide pAV.Iyy_slugft2, pAV.Iy/pAV.Iyy with input declared ', ...
         'as AVS, or SI pAV.Iyy/pAV.Iy.']);
end

% ================= GRAVITY =================
p.g = g0;

% ================= COPY DIMENSIONLESS / RADIAN FIELDS =================
% Preferred field names are copied first. These are the names currently used
% by the longitudinal SI core, so they always win if duplicate aliases exist.

passthrough = { ...
    'CL0', 'CL_alpha', 'CL_alpha_w', 'CL_alpha_t', ...
    'C_Dalpha', 'Cm_alphadot', 'Cm_q', 'eta', 'AR_w', ...
    'iw', 'it', 'epsilon0', 'dEdalpha', ...
    'Cm0', 'Cm0_w', 'Cm0_f', 'Cm_af', 'Cm_alpha', 'dCLt_ddeltaE', ...
    'C_D0', 'C_Du', 'C_Lu', ...
    'alpha_trim', 'DELTAdelta_e', ...
    'theta0', 'S_t_ratio', 'C_Z_alphadot', 'C_Z_q', 'C_m_u', ...
    'Cm_deltaE', 'C_m_deltaE', 'CL_deltaE', 'C_Z_deltaE_non_dim', ...
    'CL_alphadot', 'CL_q', 'use_direct_longitudinal_dynamic_derivatives' ...
    };

for k = 1:numel(passthrough)
    field_name = passthrough{k};
    if isfield(pAV, field_name)
        p.(field_name) = pAV.(field_name);
    end
end

% ================= COMPATIBILITY ALIASES =================
% These aliases are fallbacks only. They do not overwrite the preferred
% field names above if those fields were already supplied.

% Drag coefficient / derivatives
if ~isfield(p, 'C_D0') && isfield(pAV, 'CD0')
    p.C_D0 = pAV.CD0;
end

if ~isfield(p, 'C_Dalpha') && isfield(pAV, 'CD_alpha')
    p.C_Dalpha = pAV.CD_alpha;
elseif ~isfield(p, 'C_Dalpha') && isfield(pAV, 'CDalpha')
    p.C_Dalpha = pAV.CDalpha;
end

if ~isfield(p, 'C_Du') && isfield(pAV, 'CD_u')
    p.C_Du = pAV.CD_u;
elseif ~isfield(p, 'C_Du') && isfield(pAV, 'CDu')
    p.C_Du = pAV.CDu;
end

% Lift derivative with respect to forward-speed perturbation
if ~isfield(p, 'C_Lu') && isfield(pAV, 'CL_u')
    p.C_Lu = pAV.CL_u;
elseif ~isfield(p, 'C_Lu') && isfield(pAV, 'CLu')
    p.C_Lu = pAV.CLu;
end

% Elevator-related derivatives
if ~isfield(p, 'C_m_deltaE') && isfield(pAV, 'Cm_delta_e')
    p.C_m_deltaE = pAV.Cm_delta_e;
elseif ~isfield(p, 'C_m_deltaE') && isfield(pAV, 'Cm_deltaE')
    p.C_m_deltaE = pAV.Cm_deltaE;
end

if ~isfield(p, 'CL_deltaE') && isfield(pAV, 'CL_delta_e')
    p.CL_deltaE = pAV.CL_delta_e;
end

if ~isfield(p, 'C_Z_deltaE_non_dim') && isfield(pAV, 'CZ_delta_e_non_dim')
    p.C_Z_deltaE_non_dim = pAV.CZ_delta_e_non_dim;
elseif ~isfield(p, 'C_Z_deltaE_non_dim') && isfield(pAV, 'CZ_deltaE_non_dim')
    p.C_Z_deltaE_non_dim = pAV.CZ_deltaE_non_dim;
end

end

function is_avs_input = local_is_avs_input(pAV)
%LOCAL_IS_AVS_INPUT True when the user-declared input system is AVS.
%
% input_unit_system is preferred because it is the new explicit metadata.
% units is retained as a compatibility fallback.

unit_system = '';

if isfield(pAV, 'input_unit_system') && ~isempty(pAV.input_unit_system)
    unit_system = pAV.input_unit_system;

elseif isfield(pAV, 'units') && ~isempty(pAV.units)
    unit_system = pAV.units;
end

if isstring(unit_system)
    unit_system = char(unit_system);
end

is_avs_input = ischar(unit_system) && strcmpi(strtrim(unit_system), 'AVS');

end