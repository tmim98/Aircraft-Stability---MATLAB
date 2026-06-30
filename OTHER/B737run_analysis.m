clear; clc;

% --- Flight condition: FL370, Mach 0.74–0.79 (ISA) ---
p.rho = 0.348;           % kg/m^3  (ISA @ 37,000 ft)  [estimate from ISA]
p.u0  = 230;             % m/s     (~Mach 0.78 at FL370)

% --- Geometry (public-ish) ---
p.S    = 124.6;          % m^2  wing area
p.AR_w = 9.44;           % wing aspect ratio

p.St   = 28.99;          % m^2  horiz tail area (alt: 32.78 m^2)
p.c_bar = 3.8;           % m    MAC (3.6–4.0 m range)
p.lt    = 15.0;          % m    CG to tail AC (needs better source)

% --- CG and AC along MAC (use fractions of c_bar!) ---
x_cg_bar = 0.30;         % [-] cg at 30% MAC (estimate)
x_ac_bar = 0.25;         % [-] ac at 25% MAC (typical assumption)
p.x_cg = x_cg_bar * p.c_bar;
p.x_ac = x_ac_bar * p.c_bar;

% --- Mass / inertia (mission dependent) ---
p.m   = 65000;           % kg  typical cruise mass (choose)
p.Iyy = 7.0e6;            % kg*m^2 (rough starting estimate)
p.g   = 9.80665;

% --- Aero derivatives (NEED AVL/CFD/identified data: these are placeholders) ---
p.CL0        = 0.55;     % from L=W approx at this condition (depends on mass)
p.CL_alpha   = 5.0;      % 1/rad (estimate)
p.CL_alpha_w = 5.3;      % 1/rad (estimate)
p.CL_alpha_t = 4.0;      % 1/rad (estimate)

p.eta      = 0.9;        % tail dynamic pressure ratio (estimate)
p.dEdalpha = 0.35;       % downwash gradient (estimate)
p.epsilon0 = 0.0;        % rad (often set ~0 for linearization about small alpha)
p.iw = 0.0;              % rad (reference)
p.it = 0.0;              % rad (reference)

p.Cm0_w = -0.02;         % estimate
p.Cm0_f =  0.00;         % estimate
p.Cm_af = -0.10;         % estimate (very aircraft-specific)

p.dCLt_ddeltaE = 0.3;    % 1/rad (placeholder; replace with tail/elevator model)

p.C_D0 = 0.02;           % estimate (clean cruise)
p.C_Du = 0.0;
p.C_Lu = 0.0;

% Trim input style (your current Case A method)
p.alpha_trim = 0.03;     % rad (estimate)
p.DELTAdelta_e = 0.0;    % rad

out = SI_longitudinal_analysis(p);
