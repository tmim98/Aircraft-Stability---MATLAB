clear; clc;

% AVSRUN_ANALYSIS
% Longitudinal AVS input-and-run script.
% This file defines the longitudinal aircraft data, converts AVS inputs to SI,
% runs SI_longitudinal_analysis_grouped.m, and creates the output struct `out`.
% For the full project workflow, run run_combined_AVS_analysis_FINAL.m instead.

% ================= AVIATION-STANDARD INPUTS =================
pAV.units = 'AVS';

% Flight condition
pAV.u0_kt = 104.28;                 % knots
pAV.rho_slugft3 = 0.002378;     % sea-level ISA (slug/ft^3)

% Geometry (aviation units)
pAV.S_ft2    = 184;    % ft^2
pAV.St_ft2   = 43.0;     % ft^2
pAV.c_bar_ft = 5.7;     % ft
pAV.lt_ft    = 16;     % ft         Άσκηση 2.2 σελ 57 (68 στο PDF)

pAV.x_cg_ft  = 2.46;     % ft
pAV.x_ac_ft  = 1.23;     % ft

% Aerodynamics (dimensionless — NO conversion needed)
pAV.CL0 = 0.41;
pAV.CL_alpha   = 4.44;           % Άσκηση 4.3 157 (168 στο PDF)
pAV.CL_alpha_w = 4.3;           %Άσκηση 2.2 σελ 57 (68 στο PDF)
pAV.CL_alpha_t = 3.91;         % Άσκηση 2.2 σελ 57 (68 στο PDF)
pAV.C_Dalpha   = 0.33;
pAV.Cm_alphadot = -4.36;
pAV.Cm_q = -9.96;                 % NAVION source-table pitch damping derivative, 1/rad

pAV.eta  = 0.9;                  %??????????
pAV.AR_w = 8;                    %????????

pAV.iw = 0.017;
pAV.it = -0.017;
pAV.epsilon0 = 0.040;
pAV.dEdalpha = 0.45;

pAV.Cm0_w = -0.099;
pAV.Cm0_f = -0.037;
pAV.Cm_af =  0.12;      % 1/rad γράφει στην άσκηση 2.2 ??? 
pAV.Cm_alpha = -0.683; % direct static stability derivative, 1/rad

pAV.C_m_deltaE = -0.923;
pAV.CL_deltaE = 0.355;          % NAVION source-table elevator lift derivative, 1/rad
pAV.dCLt_ddeltaE = 0.3;                  %??????????
pAV.C_D0 = 0.05;
pAV.C_Du = 0.0;                              %?????
pAV.C_Lu = 0.0;                              %?????
pAV.use_direct_longitudinal_dynamic_derivatives = true;  % use NAVION source-table dynamic derivatives

pAV.alpha_trim   = 0.05; % rad
pAV.DELTAdelta_e = 0.05; % rad

% ===== MASS / WEIGHT (Option C supported) =====
% Provide EITHER of the following:
%pAV.W_lbf = 2645;        % Weight in pounds-force
 pAV.m_slug = 85.4;     % Alternative: mass in slugs

pAV.Iyy_slugft2 = 3000;  % slug*ft^2

% ================= CONVERT TO SI =================
pSI = AVS_to_SI(pAV);

% Ensure source-table nondimensional derivatives survive the AVS-to-SI conversion.
% These values are nondimensional, so they are copied without unit conversion.
pSI.use_direct_longitudinal_dynamic_derivatives = pAV.use_direct_longitudinal_dynamic_derivatives;
pSI.Cm_q = pAV.Cm_q;
pSI.Cm_alphadot = pAV.Cm_alphadot;
pSI.CL_deltaE = pAV.CL_deltaE;

% ================= RUN GROUPED SI LONGITUDINAL CORE =================
% Run grouped longitudinal core
out = SI_longitudinal_analysis_grouped(pSI);

% No plots are generated here.
% For the full workflow and mode-response plots, run:
%   run_combined_AVS_analysis_FINAL.m