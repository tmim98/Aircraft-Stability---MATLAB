clear; clc;

% AVSRUN_ANALYSIS
% Longitudinal AVS input-and-run script.
% Aircraft case: Boeing 747, classic 747/747-100/200 style.
%
% Flight condition basis:
%   NASA/Heffley / Nelson B747 condition 10
%   40,000 ft, Mach 0.90, W = 636636 lbf, clean configuration
%
% This file defines the longitudinal aircraft data, converts AVS inputs to SI,
% runs SI_longitudinal_analysis_grouped.m, and creates the output struct `out`.
% For the full project workflow, run run_combined_AVS_analysis_FINAL.m instead.

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

% ================= AVIATION-STANDARD INPUTS =================
pAV.units = 'AVS';
pAV.input_unit_system = 'AVS'; % User-declared input system: 'AVS' or 'SI'
pAV.aircraft = 'Boeing 747';
pAV.case_folder = case_folder;
pAV.project_folder = project_folder;

%% ================= FLIGHT CONDITION =================
pAV.u0_kt        = 516;                  % knots, approx 871 ft/s at Mach 0.90
pAV.M0           = 0.90;                 % Mach number
pAV.altitude_ft  = 40000;                % ft
pAV.qbar_psf     = 224;                  % lbf/ft^2, reference dynamic pressure
pAV.rho_slugft3  = 0.000590666686690787; % slug/ft^3, from rho = 2*q/u0^2
pAV.theta0       = 0.0;                  % rad, gamma = 0 level-trim reference

%% ================= GEOMETRY =================
pAV.S_ft2        = 5500;                 % ft^2, wing reference area
pAV.b            = 195.68;               % ft, wing span, stored for reference
pAV.c_bar_ft     = 27.31;                % ft, mean aerodynamic chord

pAV.St_ft2       = 1470.35016064;        % ft^2, horizontal-tail area
pAV.lt_ft        = 106.62729675;         % ft, horizontal-tail moment arm
pAV.AR_w         = 6.961938618181819;    % wing aspect ratio, b^2/S
pAV.AR_t         = 3.569007337034469;    % horizontal-tail aspect ratio

pAV.cg_mac       = 0.250;                % x_cg / c_bar, aft of LEMAC
pAV.ac_mac       = 0.3118712273641851;   % x_ac / c_bar, aft of LEMAC, current lumped estimate
pAV.x_cg_ft      = pAV.cg_mac * pAV.c_bar_ft; % ft, aft of LEMAC
pAV.x_ac_ft      = pAV.ac_mac * pAV.c_bar_ft; % ft, aft of LEMAC

%% ================= AERODYNAMICS =================
% Dimensionless coefficients use the current MATLAB field names.
pAV.CL0          = 0.517;                % operating-point lift coefficient, W/(q*S)
pAV.C_D0         = 0.042;                % zero/reference drag coefficient
pAV.CL_alpha     = 5.5;                  % 1/rad, airplane lift-curve slope
pAV.CL_alpha_w   = 1.988;                % 1/rad, wing lift-curve slope support value
pAV.CL_alpha_t   = 3.2287537695207176;   % 1/rad, tail support value chosen for Cm_q consistency
pAV.C_Dalpha     = 0.47;                 % 1/rad
pAV.Cm_alpha     = -1.6;                 % 1/rad, direct static-stability derivative

% Direct Cm0 value for this case.  The separated Cm0_w/Cm0_f/downwash terms
% are not known and should not be treated as physical B747 component values.
pAV.Cm0          = 0.067;                % trim-consistent direct value
pAV.Cm0_w        = NaN;                  % not used when direct Cm0 is active
pAV.Cm0_f        = NaN;                  % not used when direct Cm0 is active
pAV.Cm_af        = 0.572;                % 1/rad, lumped fuselage contribution support value

pAV.eta          = 0.95;                 % tail dynamic-pressure ratio
pAV.dEdalpha     = 0.36;                 % downwash-gradient support value
pAV.iw           = 0.0;                  % rad, not a physical B747 incidence assignment here
pAV.it           = 0.0;                  % rad, not a physical B747 incidence assignment here
pAV.epsilon0     = 0.0;                  % rad, not a physical B747 downwash assignment here

% Dynamic / speed / control derivatives gathered for the B747 case.
% Direct longitudinal dynamic derivatives are enabled for this case because
% Nelson/Heffley source-table values are available.
pAV.use_direct_longitudinal_dynamic_derivatives = true;

pAV.CL_alphadot  = 0.006;                % source lift derivative
pAV.C_Z_alphadot = -pAV.CL_alphadot;     % Z-force convention: C_Z_alphadot = -CL_alphadot
pAV.Cm_alphadot  = -9.0;                 % source pitching-moment derivative
pAV.CL_q         = 6.58;                 % source lift derivative due to pitch rate
pAV.C_Z_q        = -pAV.CL_q;            % Z-force convention: C_Z_q = -CL_q
pAV.Cm_q         = -25.0;                % source pitch-damping derivative
pAV.CL_M         = 0.20;                 % support value
pAV.CD_M         = 0.25;                 % support value
pAV.Cm_M         = -0.10;                % support value

pAV.C_Lu         = 0.180;                % speed derivative, M*C_LM
pAV.C_Du         = 0.225;                % speed derivative, M*C_DM
pAV.C_m_u        = -0.090;               % speed derivative, M*C_mM

pAV.CL_deltaE    = 0.300;                % 1/rad, elevator lift/control derivative
pAV.C_m_deltaE   = -1.200;               % 1/rad, elevator moment derivative
pAV.dCLt_ddeltaE = 0.300;                % 1/rad, support/fallback value
pAV.C_Z_deltaE_non_dim = -pAV.CL_deltaE; % Z-force convention: C_Z_deltaE = -CL_deltaE

pAV.alpha_trim   = 0.041887902;          % rad, 2.4 deg
pAV.DELTAdelta_e = 0.05;                 % rad, elevator perturbation used by current trim-response estimate

%% ================= MASS / WEIGHT =================
pAV.W_lbf        = 636636;               % lbf, aircraft weight
pAV.Iyy_slugft2  = 33100000;             % slug*ft^2, pitch inertia Iy

% ================= CONVERT TO SI =================
pSI = AVS_to_SI(pAV);

% ================= RUN GROUPED SI LONGITUDINAL CORE =================
out = SI_longitudinal_analysis_grouped(pSI);

% No plots are generated here.
% For the full workflow and mode-response plots, run:
%   run_combined_AVS_analysis_FINAL.m
