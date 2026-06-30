function p = AVS_to_SI(pAV)
%AVS_TO_SI Convert aviation-standard inputs (ft, kt, lbf, slug, slug/ft^3)
%         into SI fields expected by SI_longitudinal_analysis.m.
%
% Supports Option C: either weight (W_lbf) or mass (m_slug).
% Angles remain radians (no change).

% --- constants ---
FT2M   = 0.3048;
KT2MPS = 0.514444444444444;
LBF2N  = 4.4482216152605;
SLUG2KG = 14.59390294;

g0 = 9.80665; % SI gravity used internally in your core

p = struct();

% --- required SI fields used by your core ---
% density
if isfield(pAV,'rho_slugft3')
    p.rho = pAV.rho_slugft3 * SLUG2KG / (FT2M^3); % slug/ft^3 -> kg/m^3
elseif isfield(pAV,'rho') && isfield(pAV,'units') && strcmpi(pAV.units,'AVS')
    p.rho = pAV.rho * SLUG2KG / (FT2M^3);         % AVS convention: pAV.rho is slug/ft^3
elseif isfield(pAV,'rho')
    p.rho = pAV.rho;                              % assume SI kg/m^3 only when units are not AVS
else
    error('AVS_to_SI:MissingDensity','Provide pAV.rho_slugft3, or pAV.rho with pAV.units set correctly.');
end

% speed
if isfield(pAV,'u0_kt')
    p.u0 = pAV.u0_kt * KT2MPS; % knots -> m/s
elseif isfield(pAV,'u0') && isfield(pAV,'units') && strcmpi(pAV.units,'AVS')
    p.u0 = pAV.u0 * KT2MPS;    % AVS convention: pAV.u0 is in knots
elseif isfield(pAV,'u0')
    p.u0 = pAV.u0;             % assume SI m/s only when units are not AVS
else
    error('AVS_to_SI:MissingSpeed','Provide pAV.u0_kt, or pAV.u0 with pAV.units set correctly.');
end

% geometry
% Preferred explicit AVS field names:
%   pAV.S_ft2       = wing reference area, ft^2
%   pAV.St_ft2      = horizontal-tail reference area, ft^2
%   pAV.c_bar_ft    = mean aerodynamic chord, ft
%   pAV.lt_ft       = distance from c.g. to horizontal-tail reference point, ft
%   pAV.x_cg_ft     = center-of-gravity station, ft
%   pAV.x_ac_ft     = aerodynamic-center station, ft
%
% Generic AVS fallback names are also accepted only when pAV.units = 'AVS':
%   pAV.S, pAV.St, pAV.c_bar, pAV.lt, pAV.x_cg, pAV.x_ac

if isfield(pAV,'S_ft2')
    p.S = pAV.S_ft2 * (FT2M^2);
elseif isfield(pAV,'S') && isfield(pAV,'units') && strcmpi(pAV.units,'AVS')
    p.S = pAV.S * (FT2M^2);
elseif isfield(pAV,'S')
    p.S = pAV.S; % assume SI m^2 only when units are not AVS
else
    error('AVS_to_SI:MissingWingArea','Provide pAV.S_ft2, or pAV.S with pAV.units set correctly.');
end

if isfield(pAV,'St_ft2')
    p.St = pAV.St_ft2 * (FT2M^2);
elseif isfield(pAV,'St') && isfield(pAV,'units') && strcmpi(pAV.units,'AVS')
    p.St = pAV.St * (FT2M^2);
elseif isfield(pAV,'St')
    p.St = pAV.St; % assume SI m^2 only when units are not AVS
else
    error('AVS_to_SI:MissingTailArea','Provide pAV.St_ft2, or pAV.St with pAV.units set correctly.');
end

if isfield(pAV,'c_bar_ft')
    p.c_bar = pAV.c_bar_ft * FT2M;
elseif isfield(pAV,'c_bar') && isfield(pAV,'units') && strcmpi(pAV.units,'AVS')
    p.c_bar = pAV.c_bar * FT2M;
elseif isfield(pAV,'c_bar')
    p.c_bar = pAV.c_bar; % assume SI m only when units are not AVS
else
    error('AVS_to_SI:MissingMeanChord','Provide pAV.c_bar_ft, or pAV.c_bar with pAV.units set correctly.');
end

if isfield(pAV,'lt_ft')
    p.lt = pAV.lt_ft * FT2M;
elseif isfield(pAV,'lt') && isfield(pAV,'units') && strcmpi(pAV.units,'AVS')
    p.lt = pAV.lt * FT2M;
elseif isfield(pAV,'lt')
    p.lt = pAV.lt; % assume SI m only when units are not AVS
else
    error('AVS_to_SI:MissingTailArm','Provide pAV.lt_ft, or pAV.lt with pAV.units set correctly.');
end

if isfield(pAV,'x_cg_ft')
    p.x_cg = pAV.x_cg_ft * FT2M;
elseif isfield(pAV,'x_cg') && isfield(pAV,'units') && strcmpi(pAV.units,'AVS')
    p.x_cg = pAV.x_cg * FT2M;
elseif isfield(pAV,'x_cg')
    p.x_cg = pAV.x_cg; % assume SI m only when units are not AVS
else
    error('AVS_to_SI:MissingCG','Provide pAV.x_cg_ft, or pAV.x_cg with pAV.units set correctly.');
end

if isfield(pAV,'x_ac_ft')
    p.x_ac = pAV.x_ac_ft * FT2M;
elseif isfield(pAV,'x_ac') && isfield(pAV,'units') && strcmpi(pAV.units,'AVS')
    p.x_ac = pAV.x_ac * FT2M;
elseif isfield(pAV,'x_ac')
    p.x_ac = pAV.x_ac; % assume SI m only when units are not AVS
else
    error('AVS_to_SI:MissingAC','Provide pAV.x_ac_ft, or pAV.x_ac with pAV.units set correctly.');
end

% mass / weight
% Preferred explicit AVS field names:
%   pAV.W_lbf        = aircraft weight, lbf
%   pAV.m_slug       = aircraft mass, slugs
%
% Generic AVS fallback name is also accepted only when pAV.units = 'AVS':
%   pAV.W            = aircraft weight, lbf
%
% Non-AVS fallback:
%   pAV.m            = aircraft mass, kg

if isfield(pAV,'W_lbf') && ~isempty(pAV.W_lbf) && ~isnan(pAV.W_lbf)
    W_N = pAV.W_lbf * LBF2N;
    p.m = W_N / g0;                 % lbf -> N -> kg
elseif isfield(pAV,'m_slug') && ~isempty(pAV.m_slug) && ~isnan(pAV.m_slug)
    p.m = pAV.m_slug * SLUG2KG;     % slugs -> kg
elseif isfield(pAV,'W') && isfield(pAV,'units') && strcmpi(pAV.units,'AVS') && ~isempty(pAV.W) && ~isnan(pAV.W)
    W_N = pAV.W * LBF2N;
    p.m = W_N / g0;                 % AVS convention: pAV.W is weight in lbf
elseif isfield(pAV,'m') && (~isfield(pAV,'units') || ~strcmpi(pAV.units,'AVS')) && ~isempty(pAV.m) && ~isnan(pAV.m)
    p.m = pAV.m;                    % assume SI kg only when units are not AVS
else
    error('AVS_to_SI:MissingMass', ...
        'Provide pAV.W_lbf, pAV.m_slug, pAV.W with pAV.units=''AVS'', or pAV.m in SI kg.');
end

% inertia
% Preferred explicit AVS field name:
%   pAV.Iyy_slugft2  = pitch moment of inertia, slug*ft^2
%
% Generic AVS fallback names are also accepted only when pAV.units = 'AVS':
%   pAV.Iy or pAV.Iyy = pitch moment of inertia, slug*ft^2
%
% Non-AVS fallback:
%   pAV.Iyy or pAV.Iy = pitch moment of inertia, kg*m^2

if isfield(pAV,'Iyy_slugft2') && ~isempty(pAV.Iyy_slugft2) && ~isnan(pAV.Iyy_slugft2)
    p.Iyy = pAV.Iyy_slugft2 * SLUG2KG * (FT2M^2); % slug*ft^2 -> kg*m^2
elseif isfield(pAV,'Iy') && isfield(pAV,'units') && strcmpi(pAV.units,'AVS') && ~isempty(pAV.Iy) && ~isnan(pAV.Iy)
    p.Iyy = pAV.Iy * SLUG2KG * (FT2M^2);          % AVS convention: pAV.Iy is slug*ft^2
elseif isfield(pAV,'Iyy') && isfield(pAV,'units') && strcmpi(pAV.units,'AVS') && ~isempty(pAV.Iyy) && ~isnan(pAV.Iyy)
    p.Iyy = pAV.Iyy * SLUG2KG * (FT2M^2);         % AVS convention: pAV.Iyy is slug*ft^2
elseif isfield(pAV,'Iyy') && ~isempty(pAV.Iyy) && ~isnan(pAV.Iyy)
    p.Iyy = pAV.Iyy;                              % assume SI kg*m^2 only when units are not AVS
elseif isfield(pAV,'Iy') && ~isempty(pAV.Iy) && ~isnan(pAV.Iy)
    p.Iyy = pAV.Iy;                               % assume SI kg*m^2 only when units are not AVS
else
    error('AVS_to_SI:MissingInertia', ...
        'Provide pAV.Iyy_slugft2, pAV.Iy/pAV.Iyy with pAV.units=''AVS'', or SI pAV.Iyy/pAV.Iy.');
end

% gravity (core expects SI)
p.g = g0;

% --- copy through all dimensionless/per-rad aero and trim fields unchanged ---
% Preferred field names are copied first. These are the names currently used
% by the longitudinal SI core, so they always win if duplicate aliases exist.
passthrough = { ...
    'CL0','CL_alpha','CL_alpha_w','CL_alpha_t', ...
    'C_Dalpha','Cm_alphadot','Cm_q','eta','AR_w', ...
    'iw','it','epsilon0','dEdalpha', ...
    'Cm0','Cm0_w','Cm0_f','Cm_af','Cm_alpha','dCLt_ddeltaE', ...
    'C_D0','C_Du','C_Lu', ...
    'alpha_trim','DELTAdelta_e', ...
    'theta0','S_t_ratio','C_Z_alphadot','C_Z_q','C_m_u', ...
    'Cm_deltaE','C_m_deltaE','CL_deltaE','C_Z_deltaE_non_dim', ...
    'CL_alphadot','CL_q','use_direct_longitudinal_dynamic_derivatives' ...
};

for k = 1:numel(passthrough)
    f = passthrough{k};
    if isfield(pAV,f)
        p.(f) = pAV.(f);
    end
end

% --- compatibility aliases for aerodynamic field names ---
% These aliases are fallbacks only. They do not overwrite the preferred
% field names above if those fields were already supplied.

% Drag coefficient / derivatives
if ~isfield(p,'C_D0') && isfield(pAV,'CD0')
    p.C_D0 = pAV.CD0;
end
if ~isfield(p,'C_Dalpha') && isfield(pAV,'CD_alpha')
    p.C_Dalpha = pAV.CD_alpha;
elseif ~isfield(p,'C_Dalpha') && isfield(pAV,'CDalpha')
    p.C_Dalpha = pAV.CDalpha;
end
if ~isfield(p,'C_Du') && isfield(pAV,'CD_u')
    p.C_Du = pAV.CD_u;
elseif ~isfield(p,'C_Du') && isfield(pAV,'CDu')
    p.C_Du = pAV.CDu;
end

% Lift derivative with respect to forward-speed perturbation
if ~isfield(p,'C_Lu') && isfield(pAV,'CL_u')
    p.C_Lu = pAV.CL_u;
elseif ~isfield(p,'C_Lu') && isfield(pAV,'CLu')
    p.C_Lu = pAV.CLu;
end

% Elevator-related derivatives
if ~isfield(p,'C_m_deltaE') && isfield(pAV,'Cm_delta_e')
    p.C_m_deltaE = pAV.Cm_delta_e;
elseif ~isfield(p,'C_m_deltaE') && isfield(pAV,'Cm_deltaE')
    p.C_m_deltaE = pAV.Cm_deltaE;
end

if ~isfield(p,'CL_deltaE') && isfield(pAV,'CL_delta_e')
    p.CL_deltaE = pAV.CL_delta_e;
end

if ~isfield(p,'C_Z_deltaE_non_dim') && isfield(pAV,'CZ_delta_e_non_dim')
    p.C_Z_deltaE_non_dim = pAV.CZ_delta_e_non_dim;
elseif ~isfield(p,'C_Z_deltaE_non_dim') && isfield(pAV,'CZ_deltaE_non_dim')
    p.C_Z_deltaE_non_dim = pAV.CZ_deltaE_non_dim;
end

end