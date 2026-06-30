clear; clc;

% AVS_INPUT_LATERAL_NAVION
% NAVION General Aviation aircraft data for the lateral/directional module.
% Aviation-standard master inputs: ft, ft^2, slugs / lbf, knots.
% Angular quantities are kept in radians for consistency with the existing
% longitudinal scripts and with most coefficient derivatives used in Nelson.
%
% Source basis:
% - NAVION GA.xlsx (shared aircraft data + textbook reference derivatives)
% - Directional - Yaw - Roll.docx (scope of the lateral/directional build)
% This file is intentionally input-only for now.
% It does NOT call a lateral core yet.

pAV.units = 'AVS';
pAV.aircraft = 'NAVION General Aviation';

%% ================= FLIGHT CONDITION =================
pAV.u0_kt         = 105.34;      % knots
pAV.rho_slugft3   = 0.002378;    % sea-level ISA, slug/ft^3
pAV.M0            = 0.158;       % Appendix data condition in workbook

%% ================= MASS / INERTIA ==================
pAV.W_lbf         = 2750;        % lbf
pAV.Ix_slugft2    = 1048;        % slug*ft^2
pAV.Iy_slugft2    = 3000;        % slug*ft^2
pAV.Iz_slugft2    = 3530;        % slug*ft^2
pAV.Ixz_slugft2   = 0;           % slug*ft^2

%% ================= REFERENCE GEOMETRY ==============
pAV.S_ft2         = 184;         % wing area, ft^2
pAV.b_ft          = 33.4;        % wingspan, ft
pAV.c_bar_ft      = 5.7;         % mean aerodynamic chord, ft
pAV.x_cg_MAC      = 0.295;       % x_cg / c_bar
pAV.x_ac_MAC      = 0.25;        % x_ac / c_bar
pAV.x_cg_ft       = pAV.x_cg_MAC * pAV.c_bar_ft;
pAV.x_ac_ft       = pAV.x_ac_MAC * pAV.c_bar_ft;

%% ================= WING / AILERON GEOMETRY =========
pAV.Cmac_w        = -0.116;
pAV.CLalpha_w     = 0.097 * (180/pi);   % workbook value was 0.097 per deg
pAV.alpha0L_w_deg = -5;                  % deg
pAV.twist_w_deg   = 0;                   % deg
pAV.iw            = deg2rad(1);          % rad

% Quantities already tabulated in the workbook and likely useful later
% for roll-control relations (Nelson Sec. 2.9 / pure rolling motion).
pAV.lambda_taper  = 0.54;        % wing taper ratio
pAV.c_root_ft     = 7.2;         % ft
pAV.c_tip_ft      = 3.9;         % ft
pAV.y1_ft         = 11.1;        % inboard aileron station, ft
pAV.y2_ft         = 16.0;        % outboard aileron station, ft
pAV.ca_over_c     = 0.18;        % aileron chord ratio

%% ================= HORIZONTAL TAIL (shared) ========
pAV.St_ft2        = 43.0;        % ft^2
pAV.lt_ft         = 16.0;        % ft
pAV.it            = deg2rad(-1); % rad
pAV.AR_t          = 6.06;
pAV.CLalpha_t     = 0.01 * (180/pi);    % workbook value was 0.01 per deg
pAV.CLalpha_wb    = 4.3;         % 1/rad, workbook row C_L_alpha_w
pAV.CL0_w         = 0.375;
pAV.Cm0_w         = -0.099;
pAV.Cm_alpha_w    = 0.1935;      % 1/rad
pAV.VH            = 0.66;
pAV.epsilon0      = 0.04;        % rad
pAV.Cm0_t         = 0.194;
pAV.Cm_alpha_t    = -1.42;       % 1/rad
pAV.Cm0_f         = -0.037;

%% ================= VERTICAL TAIL / RUDDER ===========
% These are the fields I expect the lateral core to need if we follow
% Nelson's directional-stability / rudder-effectiveness development using
% geometry and chart-based corrections.
% The current workbook does not appear to include them explicitly, so they
% are left as placeholders until we decide how far we go with the geometry-
% based build versus using the textbook reference derivatives directly.
pAV.Sv_ft2        = NaN;          % vertical tail area, ft^2
pAV.lv_ft         = NaN;          % c.g. to vertical tail AC / quarter-chord, ft
pAV.zv_ft         = NaN;          % vertical location of vertical tail AC, ft
pAV.AR_v          = NaN;          % vertical tail aspect ratio
pAV.CLalpha_v     = NaN;          % vertical tail lift-curve slope, 1/rad
pAV.eta_v         = NaN;          % q_v / q_w
pAV.tau_r         = NaN;          % rudder effectiveness factor
pAV.S_r_over_Sv   = NaN;          % rudder-to-vertical-tail area ratio
pAV.br_over_bv    = NaN;          % rudder span ratio on the fin
pAV.sweep_quarter_w_deg = NaN;    % wing quarter-chord sweep, deg
pAV.S_bs_ft2      = NaN;          % projected side area of aircraft, ft^2
pAV.l_f_ft        = NaN;          % fuselage length, ft
pAV.kN            = NaN;          % wing-body interference factor (Fig. 2.29)
pAV.kRl           = NaN;          % fuselage Reynolds correction (Fig. 2.30)

%% ================= REFERENCE LONGITUDINAL DATA =====
% Kept here because the final project target is a unified AVS input file.
% These values already exist in the workbook and can later be merged with
% the longitudinal AVS runner if desired.
pAV.CL0           = 0.41;
pAV.CD0           = 0.05;
pAV.CL_alpha      = 4.44;
pAV.CD_alpha      = 0.33;
pAV.Cm_alpha      = -0.683;
pAV.CL_alphadot   = 0.0;
pAV.Cm_alphadot   = -4.36;
pAV.CL_q          = 3.8;
pAV.Cm_q          = -9.96;
pAV.CL_M          = 0.0;
pAV.CD_M          = 0.0;
pAV.Cm_M          = 0.0;
pAV.CL_delta_e    = 0.355;
pAV.Cm_delta_e    = -0.923;

%% ================= LATERAL / DIRECTIONAL REFERENCE DERIVATIVES =====
% Textbook / workbook reference values for the NAVION.
% These are useful both as direct inputs and as validation targets once the
% geometry-based lateral core is implemented.
pAV.CY_beta       = -0.564;
pAV.Cl_beta       = -0.074;
pAV.Cn_beta       = -0.071;

pAV.Cl_p          = -0.410;
pAV.Cn_p          = -0.0575;
pAV.Cl_r          =  0.107;
pAV.Cn_r          = -0.125;

pAV.Cl_delta_a    = -0.134;
pAV.Cn_delta_a    = -0.0035;
pAV.CY_delta_r    =  0.157;
pAV.Cl_delta_r    =  0.107;
pAV.Cn_delta_r    = -0.072;

%% ================= OPTIONAL PLACEHOLDERS ============
% Depending on the exact state-space form we adopt, these may be useful.
pAV.g_fts2        = 32.174;      % ft/s^2
pAV.theta0        = 0.0;         % rad
pAV.phi0          = 0.0;         % rad

%% ================= SANITY DISPLAY ===================
disp('Lateral/directional AVS input struct created: pAV');
disp('This is an input-only file; no lateral core is called yet.');
