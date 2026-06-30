% AVS_INPUT_LATERAL_CURRENT
% Lateral/directional AVS input-and-run script for the current aircraft.
% Aircraft case: Boeing 747, classic 747/747-100/200 style.
%
% Flight condition basis:
%   NASA/Heffley / Nelson B747 condition 10
%   40,000 ft, Mach 0.90, W = 636636 lbf, clean configuration
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
% 3) Direct B747 reference derivatives are supplied and should remain active.
% 4) Nelson-style estimates may still be calculated for reporting/comparison.

% ================= PATH SETUP =================
% Allows this case file to live either in the project root or in:
%   aircraft_cases/B747/
case_folder = fileparts(mfilename('fullpath'));
if isempty(case_folder)
    case_folder = pwd;
end

project_folder = case_folder;
[parent_folder, parent_name] = fileparts(case_folder);
if strcmpi(parent_name, 'B747')
    [grandparent_folder, grandparent_name] = fileparts(parent_folder);
    if strcmpi(grandparent_name, 'aircraft_cases')
        project_folder = grandparent_folder;
    end
end
addpath(project_folder);

pAV.units = 'AVS';
pAV.aircraft = 'Boeing 747';
pAV.case_folder = case_folder;
pAV.project_folder = project_folder;

%% ================= FLIGHT CONDITION =================
pAV.u0  = 516;                       % knots, approx 871 ft/s at Mach 0.90
pAV.M0  = 0.90;                      % Mach number
pAV.altitude_ft = 40000;             % ft
pAV.qbar_psf = 224;                  % lbf/ft^2, reference dynamic pressure
pAV.rho = 0.000590666686690787;      % slug/ft^3, from rho = 2*q/u0^2

%% ================= MASS / INERTIA ==================
pAV.W   = 636636;       % lbf
pAV.Ix  = 18200000;     % slug*ft^2
pAV.Iy  = 33100000;     % slug*ft^2, stored for reference; current lateral core does not use Iy
pAV.Iz  = 49700000;     % slug*ft^2
pAV.Ixz = 970056;       % slug*ft^2, stored; current lateral core still ignores Ixz coupling

%% ================= REFERENCE GEOMETRY ==============
pAV.S      = 5500;                 % ft^2, wing reference area
pAV.b      = 195.68;               % ft, wing span
pAV.c_bar  = 27.31;                % ft, mean aerodynamic chord
pAV.cg_mac = 0.250;                % x_cg / c_bar, aft of LEMAC
pAV.ac_mac = 0.3118712273641851;   % x_ac / c_bar, aft of LEMAC, current lumped estimate
pAV.x_cg   = pAV.cg_mac * pAV.c_bar; % ft, aft of LEMAC
pAV.x_ac   = pAV.ac_mac * pAV.c_bar; % ft, aft of LEMAC

%% ================= WING / AILERON GEOMETRY =========
pAV.Cmac_w = NaN;                  % not used by current active lateral direct derivatives
pAV.CLa_w  = 1.988;                % 1/rad, wing lift-curve slope support value
pAV.alpha0L_w = NaN;               % deg, not used
pAV.i_twist_w = NaN;               % deg, not used
pAV.iw = 0.0;                      % rad, not a physical B747 incidence assignment here

pAV.TaperRatio = 0.284;            % wing taper ratio from sheet
pAV.c_root = NaN;                  % ft, not gathered yet
pAV.c_tip  = NaN;                  % ft, not gathered yet
pAV.y1     = NaN;                  % ft, not gathered yet
pAV.y2     = NaN;                  % ft, not gathered yet
pAV.ca_c   = NaN;                  % aileron chord ratio, not gathered yet
pAV.Gamma_w = NaN;                 % deg, wing dihedral not from NASA GAMMA flight-path angle

%% ================= HORIZONTAL TAIL (shared) ========
pAV.St      = 1470.35016064;       % ft^2, horizontal-tail area
pAV.lt      = 106.62729675;        % ft, horizontal-tail moment arm
pAV.it      = 0.0;                 % rad, not a physical B747 incidence assignment here
pAV.AR_t    = 3.569007337034469;   % horizontal-tail aspect ratio
pAV.CL_alpha_t = 3.2287537695207176; % 1/rad, support value chosen for Cm_q consistency
pAV.CL_alpha_w = 1.988;            % 1/rad
pAV.CL0_w      = NaN;              % not used by current active lateral direct derivatives
pAV.Cm0        = 0.067;            % direct trim-consistent value
pAV.Cm0_w      = NaN;              % not used when direct Cm0 is active
pAV.Cm_alpha_w = NaN;              % not used by current active lateral direct derivatives
pAV.epsilon0   = 0.0;              % rad, not a physical B747 downwash assignment here
pAV.Cm0_t      = NaN;              % not used by current active lateral direct derivatives
pAV.Cm_alpha_t = NaN;              % not used by current active lateral direct derivatives
pAV.Cm0_f      = NaN;              % not used when direct Cm0 is active

%% ================= VERTICAL TAIL / RUDDER ==========
pAV.Sv      = 829.89749184;        % ft^2, vertical-tail area
pAV.lv      = 98.425197;           % ft, vertical-tail moment arm
pAV.bv      = 33.333333384;        % ft, vertical-tail span/height
pAV.zv      = NaN;                 % ft, not used yet
pAV.AR_v    = 1.3388534432432115;  % vertical-tail aspect ratio
pAV.Cla_v   = 2.52;                % 1/rad, vertical-tail lift-curve slope support value
pAV.eta_v   = NaN;                 % q_v/q, kept separate placeholder for now
pAV.tau_r   = NaN;                 % rudder effectiveness factor, not gathered yet
pAV.Sr_Sv   = NaN;                 % rudder area ratio, not gathered yet
pAV.br_bv   = NaN;                 % rudder span ratio, not gathered yet

% Wing / fuselage quantities needed for Nelson Eq. [2.80]
pAV.sweep_w  = 37.5;              % deg, wing quarter-chord sweep used for CY_p support
pAV.sweep_c4w = 37.5;              % deg, wing quarter-chord sweep used in Eq. [2.80]
pAV.z_w      = 0.20;              % ft, estimated wing vertical location support value
pAV.d        = 26.57;              % ft, maximum fuselage depth/height used for Eq. [2.80]

% Fuselage / wing-body geometry for Nelson Eq. [2.73], Fig. 2.29, Fig. 2.30.
% These are support/reporting quantities only because direct Cn_beta is supplied.
pAV.S_fs = NaN;                   % ft^2, fuselage/body projected side area not gathered yet
pAV.l_f  = 225.17;                % ft, fuselage length
pAV.x_m  = NaN;                   % ft, not gathered yet
pAV.h    = NaN;                   % ft, not gathered yet
pAV.h1   = NaN;                   % ft, not gathered yet
pAV.h2   = NaN;                   % ft, not gathered yet
pAV.w_f  = 21.33;                 % ft, fuselage width / equivalent body diameter

pAV.nu   = NaN;                   % ft^2/s, not needed while direct derivatives are active
pAV.kN   = NaN;                   % optional direct override for wing-body interference factor, Fig. 2.29
pAV.kRl  = NaN;                   % optional direct override for fuselage Reynolds correction, Fig. 2.30

%% ================= LONGITUDINAL REFERENCE DATA =====
% Included here only to support the eventual transition to a unified AVS
% input file while the cores remain separate.
pAV.CL0          = 0.517;
pAV.CL          = pAV.CL0;              % use CL0 for current CY_p estimate
pAV.AR          = pAV.b^2 / pAV.S;      % wing aspect ratio
pAV.CL_alpha_v  = pAV.Cla_v;            % naming alias for consistency in core
pAV.S_v         = pAV.Sv;               % naming alias for consistency in core
pAV.l_v         = pAV.lv;               % naming alias for consistency in core
pAV.R_280       = 1.04805998668665;     % direct support value from sheet/calculation

pAV.CD0         = 0.042;
pAV.CL_alpha    = 5.5;
pAV.CD_alpha    = 0.47;
pAV.Cm_alpha    = -1.6;
pAV.CL_alphadot = 0.006;
pAV.Cm_alphadot = -9.0;
pAV.CL_q        = 6.58;
pAV.Cm_q        = -25.0;
pAV.CL_M        = 0.20;
pAV.CD_M        = 0.25;
pAV.Cm_M        = -0.10;
pAV.CL_delta_e  = 0.300;
pAV.Cm_delta_e  = -1.200;

%% ================= LATERAL / DIRECTIONAL REFERENCE DERIVATIVES =====
% Direct B747 derivatives for the current sign convention.
pAV.CY_beta    = -0.85;
pAV.Cl_beta    = -0.10;
pAV.Cn_beta    =  0.20;

pAV.Cl_p       = -0.30;
pAV.Cn_p       =  0.20;
pAV.Cl_r       =  0.20;
pAV.Cn_r       = -0.325;

pAV.Cl_delta_a =  0.014;
pAV.Cn_delta_a =  0.003;
pAV.CY_delta_r =  0.075;
pAV.use_zero_CY_delta_r = false;
pAV.Cl_delta_r =  0.005;
pAV.Cn_delta_r = -0.09;   % current tool/NAVION sign convention: CY_dr > 0, Cl_dr > 0, Cn_dr < 0

%% ================= OPTIONAL PLACEHOLDERS ==========
pAV.g      = 32.174;  % ft/s^2
pAV.theta0 = 0.0;     % rad
pAV.phi0   = 0.0;     % rad

%% ================= DIGITIZED FIGURE REFERENCES =====
% Shared digitized Nelson figure data are expected in the project root:
%   project_folder/Digitalized Figs/
pAV.digitized_figures_folder = fullfile(pAV.project_folder, 'Digitalized Figs');

pAV.fig_2_29_csv = fullfile(pAV.digitized_figures_folder, ...
    'wing_body_interference_kn_digitized_v3_final.csv');

pAV.fig_3_11_csv = fullfile(pAV.digitized_figures_folder, ...
    'figure_3_11_digitized_second_pass.csv');

pAV.fig_3_12_csv = fullfile(pAV.digitized_figures_folder, ...
    'fig3_12_digitized_K_vs_eta_lambda_0_5.csv');

out_lat = AVS_lateral_directional_analysis(pAV);
