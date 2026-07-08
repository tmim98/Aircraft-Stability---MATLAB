
% AVS_INPUT_LATERAL_CURRENT
% Lateral/directional AVS input-and-run script for the current aircraft.
%
% This file defines the lateral/directional aircraft data, then runs
% AVS_lateral_directional_analysis.m and creates the output struct `out_lat`.
% For the full project workflow, run run_combined_AVS_analysis_FINAL.m instead.
%
% Master unit system for this file: AVS
% Length   : ft
% Area     : ft^2
% Speed    : knots for u0
% Weight   : lbf
% Inertia  : slug*ft^2
% Density  : slug/ft^3
% Angles   : radians unless otherwise noted in comments
%
% Notes:
% 1) This file intentionally defines inputs AND runs the lateral core.
% 2) Variable names are kept clean; units are documented in comments.
% 3) Chart/digitized-data based quantities are left as placeholders unless
%    they are directly tabulated in the uploaded workbook.
%
% Source basis:
% - NAVION GA.xlsx
% - Directional - Yaw - Roll.docx
% - figure_2_29_digitized_families_v3.csv
% - figure_2_30_digitized_samples.csv
% - fig3_12_digitized_K_vs_eta_lambda_0_5.csv

pAV.units = 'AVS';
pAV.input_unit_system = 'AVS'; % User-declared input system: 'AVS' or 'SI'
pAV.aircraft = 'NAVION General Aviation';   % current case-study aircraft name

%% ================= FLIGHT CONDITION =================
pAV.u0  = 104.28;     % knots
pAV.M0  = 0.158;      % sea-level workbook condition
pAV.rho = 0.002378;   % slug/ft^3, sea-level ISA

%% ================= MASS / INERTIA ==================
pAV.W   = 2750;       % lbf
pAV.Ix  = 1048;       % slug*ft^2
pAV.Iy  = 3000;       % slug*ft^2
pAV.Iz  = 3530;       % slug*ft^2
pAV.Ixz = 0;          % slug*ft^2

%% ================= REFERENCE GEOMETRY ==============
pAV.S      = 184;                 % ft^2
pAV.b      = 33.4;                % ft
pAV.c_bar  = 5.7;                 % ft
pAV.x_cg   = 0.295 * pAV.c_bar;   % ft
pAV.x_ac   = 0.25  * pAV.c_bar;   % ft
pAV.cg_mac = 0.295;               % x_cg / c_bar
pAV.ac_mac = 0.25;                % x_ac / c_bar

%% ================= WING / AILERON GEOMETRY =========
pAV.Cmac_w = -0.116;
pAV.CLa_w  = 0.097 * (180/pi);    % 1/rad; workbook gives 0.097 per degree
pAV.alpha0L_w = -5;               % deg
pAV.i_twist_w   = 0;                % deg
pAV.iw        = deg2rad(1);       % rad

% Aileron / planform quantities already tabulated in the workbook
pAV.TaperRatio = 0.54;                % taper ratio
pAV.c_root = 7.2;                 % ft
pAV.c_tip  = 3.9;                 % ft
pAV.y1     = 11.1;                % ft, inboard aileron station
pAV.y2     = 16.0;                % ft, outboard aileron station
pAV.ca_c   = 0.18;                % aileron chord ratio (dimensionless)
pAV.Gamma_w = 7.5;                % deg, wing dihedral angle; needed for Fig. 3.11 Cl_beta estimate

%% ================= HORIZONTAL TAIL (shared) ========
% Kept here because these aircraft data are shared with the longitudinal side
% and will help future unification of the AVS input file.
pAV.St      = 43.0;               % ft^2
pAV.lt      = 16.0;               % ft
pAV.it      = deg2rad(-1);        % rad
pAV.AR_t    = 6.06;
pAV.CL_alpha_t   = 3.91;        % 1/rad
pAV.CL_alpha_w = 4.3;             % 1/rad
pAV.CL0_w      = 0.375;
pAV.Cm0_w      = -0.099;
pAV.Cm_alpha_w = 0.1935;          % 1/rad
%pAV.VH         = 0.66;
pAV.epsilon0   = 0.04;            % rad
pAV.Cm0_t      = 0.194;
pAV.Cm_alpha_t = -1.42;           % 1/rad
pAV.Cm0_f      = -0.037;

%% ================= VERTICAL TAIL / RUDDER ==========
% Working values estimated from current aircraft drawings / geometry reconstruction.
pAV.Sv      = 13.0;       % ft^2
pAV.lv      = 6.8;        % ft
pAV.bv      = 5.07;       % ft
pAV.zv      = NaN;        % ft, not used yet
pAV.AR_v    = 1.9773;     % vertical-tail aspect ratio
pAV.Cla_v   = 2.957;      % 1/rad, estimated vertical-tail lift-curve slope
pAV.eta_v   = NaN;        % q_v / q (kept separate placeholder for now)
pAV.tau_r   = NaN;        % rudder effectiveness factor
pAV.Sr_Sv   = 0.4108;     % rudder area ratio
pAV.br_bv   = NaN;        % rudder span ratio on vertical tail

% Wing / fuselage quantities needed for Nelson Eq. [2.80]
pAV.sweep_w = 2.929444;    % deg, wing sweep Lambda (used for CY_p)
pAV.sweep_c4w = 0.12;      % deg, wing quarter-chord sweep Lambda_c/4,w (used in Eq. [2.80])
pAV.z_w     = 1.2;        % ft, positive downward
pAV.d       = 3.9167;     % ft, maximum fuselage depth

% Fuselage / wing-body geometry for Nelson Eq. [2.73], Fig. 2.29, Fig. 2.30.
% Fill these values from the digitized geometry before relying on Cn_beta_wf.
% S_fs, h, h1, and h2 are digitization-sensitive.
% w_f is considered solid.
% x_m is reasonably solid but depends on the inferred MAC leading-edge station.

pAV.S_fs = 85.6;           % ft^2, fuselage/body projected side area, Nelson S_fs

pAV.l_f  = 26.6;           % ft, fuselage length
pAV.x_m  = 7.75;           % ft, distance from fuselage nose/reference to C.G./moment reference

pAV.h    = 5.47;           % ft, body height used in Fig. 2.29 h/w_f
pAV.h1   = 5.21;           % ft, Fig. 2.29 upper/lower body-height input
pAV.h2   = 2.92;           % ft, Fig. 2.29 upper/lower body-height input
pAV.w_f  = 3.92;           % ft, maximum body width

pAV.nu   = 1.572e-4;      % ft^2/s, sea-level standard kinematic viscosity; update for non-sea-level cases

pAV.kN   = NaN;           % optional direct override for wing-body interference factor, Fig. 2.29
pAV.kRl  = NaN;           % optional direct override for fuselage Reynolds correction, Fig. 2.30

% ================= LONGITUDINAL REFERENCE DATA =====
% Included here only to support the eventual transition to a unified AVS
% input file while the cores remain separate.
pAV.CL0        = 0.41;
% ----- Support fields for lateral/directional CY estimates -----
pAV.CL         = pAV.CL0;              % use CL0 for current CY_p estimate
pAV.AR         = pAV.b^2 / pAV.S;      % wing aspect ratio
pAV.CL_alpha_v = pAV.Cla_v;            % naming alias for consistency in core
pAV.S_v        = pAV.Sv;               % naming alias for consistency in core
pAV.l_v        = pAV.lv;               % naming alias for consistency in core
R = 0.724 ...
  + 3.06 * ((pAV.S_v / pAV.S) / (1 + cosd(pAV.sweep_c4w))) ...
  + 0.4  * (pAV.z_w / pAV.d) ...
  + 0.009 * pAV.AR;

pAV.R_280      = R;      % Nelson Eq. [2.80] LHS= eta*(1 + dSigma/dBeta)
pAV.CD0        = 0.05;
pAV.CL_alpha   = 4.44;
pAV.CD_alpha   = 0.33;
pAV.Cm_alpha   = -0.683;
pAV.CL_alphadot = 0.0;
pAV.Cm_alphadot = -4.36;
pAV.CL_q       = 3.8;
pAV.Cm_q       = -9.96;
pAV.CL_M       = 0.0;
pAV.CD_M       = 0.0;
pAV.Cm_M       = 0.0;
pAV.CL_delta_e = 0.355;
pAV.Cm_delta_e = -0.923;

%% ================= LATERAL / DIRECTIONAL REFERENCE DERIVATIVES =====
% Reference values for the current aircraft/case. These can be used directly as
% validation targets or as supplied derivatives for the lateral/directional core.
pAV.CY_beta    = -0.564;
pAV.Cl_beta    = -0.074;
pAV.Cn_beta    =  0.071;

pAV.Cl_p       = -0.410;
pAV.Cn_p       = -0.0575;
pAV.Cl_r       =  0.107;
pAV.Cn_r       = -0.125;

pAV.Cl_delta_a =  0.134;
pAV.Cn_delta_a = -0.0035;
pAV.CY_delta_r =  0.157;
pAV.use_zero_CY_delta_r = false;
pAV.Cl_delta_r =  0.0118;
pAV.Cn_delta_r = -0.072;

%% ================= OPTIONAL PLACEHOLDERS ==========
pAV.g      = 32.174;  % ft/s^2
pAV.theta0 = 0.0;     % rad
pAV.phi0   = 0.0;     % rad

%% ================= DIGITIZED FIGURE REFERENCES =====
% Robust path setup for digitized Nelson figure data.
% The CSV files should be stored in:
%   project_folder/Digitalized Figs/

pAV.project_folder = fileparts(mfilename('fullpath'));
pAV.digitized_figures_folder = fullfile(pAV.project_folder, 'Digitalized Figs');

pAV.fig_2_29_csv = fullfile(pAV.digitized_figures_folder, ...
    'wing_body_interference_kn_digitized_v3_final.csv');

pAV.fig_3_11_csv = fullfile(pAV.digitized_figures_folder, ...
    'figure_3_11_digitized_second_pass.csv');

pAV.fig_3_12_csv = fullfile(pAV.digitized_figures_folder, ...
    'fig3_12_digitized_K_vs_eta_lambda_0_5.csv');


out_lat = AVS_lateral_directional_analysis(pAV);