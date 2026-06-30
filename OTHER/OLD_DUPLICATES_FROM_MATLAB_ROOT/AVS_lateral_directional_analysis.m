function out = AVS_lateral_directional_analysis(pAV)
% AVS_LATERAL_DIRECTIONAL_ANALYSIS
% Lateral/directional analysis core for the NAVION project.
%
% This first version implements only:
%   1) interface and assumptions
%   2) input unpacking / validation / bookkeeping
%   3) derivative-preparation block in AVS-consistent units
%
% It does NOT yet assemble the lateral state matrix.
% It does NOT yet compute eigenvalues or mode classification.
%
% Intended data source:
%   AVS_input_lateral_NAVION_clean.m
%
% Master input unit system (AVS):
%   Length   : ft
%   Area     : ft^2
%   Speed    : knots for u0 (converted locally to ft/s where needed)
%   Weight   : lbf
%   Inertia  : slug*ft^2
%   Density  : slug/ft^3
%   Angles   : radians unless otherwise noted in comments
%
% Notes:
%   - Variable names intentionally do NOT carry unit suffixes.
%   - Units are documented here and in the input file comments.
%   - This file reads the lateral input struct directly.
%   - For now, the derivative block uses the workbook reference lateral
%     derivatives already present in pAV.
%   - Geometry-based derivative estimation from Nelson can be added later,
%     chapter by chapter, without changing this interface.
%
% Usage:
%   out = AVS_lateral_directional_analysis(pAV)
%
%   or, if you want the function to load the current script-based input file:
%   out = AVS_lateral_directional_analysis()
%
% Expected current input source fields include:
%   pAV.u0, pAV.rho, pAV.W, pAV.S, pAV.b, pAV.c_bar,
%   pAV.Ix, pAV.Iz, pAV.Ixz, pAV.g,
%   pAV.CY_beta, pAV.Cl_beta, pAV.Cn_beta,
%   pAV.Cl_p, pAV.Cn_p, pAV.Cl_r, pAV.Cn_r,
%   pAV.Cl_delta_a, pAV.Cn_delta_a,
%   pAV.CY_delta_r, pAV.Cl_delta_r, pAV.Cn_delta_r
%
% Future extensions planned:
%   - full lateral/directional state matrix
%   - exact mode extraction (roll / spiral / Dutch roll)
%   - Nelson approximations from Chapter 5
%   - geometry-based derivative estimation from Chapter 2 / Table 3.4
%
% -------------------------------------------------------------------------
% 1) Load / validate inputs
% -------------------------------------------------------------------------
if nargin < 1 || isempty(pAV)
    run('AVS_input_lateral_NAVION_clean.m');
end

if ~exist('pAV','var') || ~isstruct(pAV)
    error('AVS_lateral_directional_analysis:MissingInput', ...
        ['Input struct pAV was not supplied and could not be created by ', ...
         'running AVS_input_lateral_NAVION_clean.m.']);
end

% -------------------------------------------------------------------------
% 2) Defaults and high-level assumptions
% -------------------------------------------------------------------------
if ~isfield(pAV,'units') || isempty(pAV.units)
    pAV.units = 'AVS';
end

if ~isfield(pAV,'aircraft') || isempty(pAV.aircraft)
    pAV.aircraft = 'Unknown aircraft';
end

if ~isfield(pAV,'g') || isempty(pAV.g) || isnan(pAV.g)
    pAV.g = 32.174; % ft/s^2
end

if ~isfield(pAV,'theta0') || isempty(pAV.theta0) || isnan(pAV.theta0)
    pAV.theta0 = 0.0; % rad
end

if ~isfield(pAV,'phi0') || isempty(pAV.phi0) || isnan(pAV.phi0)
    pAV.phi0 = 0.0; % rad
end

% Current convention note for this staged build:
% - beta is treated as the primary lateral translational perturbation state
%   for derivative bookkeeping.
% - Rate derivatives with respect to p and r use the standard nondimensional
%   forms based on b/(2*u0).
% - No state matrix is assembled in this version.

% -------------------------------------------------------------------------
% 3) Required-field validation
% -------------------------------------------------------------------------
requiredFields = {
    'u0', 'rho', 'W', ...
    'S', 'b', 'c_bar', ...
    'Ix', 'Iz', 'Ixz', ...
    'CY_beta', 'Cl_beta', 'Cn_beta', ...
    'Cl_p', 'Cn_p', 'Cl_r', 'Cn_r', ...
    'CY_delta_r', 'Cl_delta_r'
    };

missingFields = {};
for k = 1:numel(requiredFields)
    f = requiredFields{k};
    if ~isfield(pAV,f) || isempty(pAV.(f)) || any(isnan(pAV.(f)))
        missingFields{end+1} = f; %#ok<AGROW>
    end
end

if ~isempty(missingFields)
    error('AVS_lateral_directional_analysis:MissingFields', ...
        'Missing required pAV field(s): %s', strjoin(missingFields, ', '));
end

% -------------------------------------------------------------------------
% 4) Unpack AVS inputs
% -------------------------------------------------------------------------
% Flight condition
u0    = pAV.u0;      % knots
rho   = pAV.rho;     % slug/ft^3
W     = pAV.W;       % lbf

g     = pAV.g;       % ft/s^2
theta0 = pAV.theta0; % rad
phi0   = pAV.phi0;   % rad

% Geometry
S     = pAV.S;       % ft^2
b     = pAV.b;       % ft
c_bar = pAV.c_bar;   % ft

% Inertia
Ix  = pAV.Ix;        % slug*ft^2
Iz  = pAV.Iz;        % slug*ft^2
Ixz = pAV.Ixz;       % slug*ft^2

% Nondimensional stability derivatives (reference values from workbook)
CY_beta = pAV.CY_beta;
Cl_beta = pAV.Cl_beta;
Cn_beta = pAV.Cn_beta;

Cl_p = pAV.Cl_p;
Cn_p = pAV.Cn_p;
Cl_r = pAV.Cl_r;
Cn_r = pAV.Cn_r;

% Control derivatives:
% Use supplied values when available. If selected derivatives are missing,
% estimate them using Nelson-based methods.

Cl_delta_r = pAV.Cl_delta_r;

% Always calculate Nelson estimates for reporting/comparison.
% These are stored later in out.nelson_estimates and are clearly separate
% from the active derivatives used in the state-space model.
[Cl_delta_a_Nelson, info_Cl_delta_a_Nelson] = avs_estimate_Cl_delta_a_Nelson(pAV);
[Cn_delta_r_Nelson, info_Cn_delta_r_Nelson] = avs_estimate_Cn_delta_r_Nelson(pAV);
[Cn_delta_a_Nelson, info_Cn_delta_a_Nelson] = avs_estimate_Cn_delta_a_Nelson(pAV, Cl_delta_a_Nelson);

% Aileron rolling-moment derivative, Cl_delta_a:
% Prefer the input-file value. If missing, use the Nelson Eq. [2.96] estimate.
if isfield(pAV, 'Cl_delta_a') && ~isempty(pAV.Cl_delta_a) && isfinite(pAV.Cl_delta_a)
    Cl_delta_a = pAV.Cl_delta_a;
    src_Cl_delta_a = 'input';
    info_Cl_delta_a = struct();
    info_Cl_delta_a.method = 'supplied directly in pAV.Cl_delta_a';
    info_Cl_delta_a.used_estimate = false;
else
    Cl_delta_a = Cl_delta_a_Nelson;
    src_Cl_delta_a = 'estimated_Nelson_Eq_2_96';
    info_Cl_delta_a = info_Cl_delta_a_Nelson;
end

% Aileron yawing-moment derivative, Cn_delta_a:
% Prefer the input-file value. If missing, use Nelson Table 3.4 with K from Fig. 3.12.
if isfield(pAV, 'Cn_delta_a') && ~isempty(pAV.Cn_delta_a) && isfinite(pAV.Cn_delta_a)
    Cn_delta_a = pAV.Cn_delta_a;
    src_Cn_delta_a = 'input';
    info_Cn_delta_a = struct();
    info_Cn_delta_a.method = 'supplied directly in pAV.Cn_delta_a';
    info_Cn_delta_a.used_estimate = false;
else
    Cn_delta_a = Cn_delta_a_Nelson;
    src_Cn_delta_a = 'estimated_Nelson_Table_3_4_Fig_3_12';
    info_Cn_delta_a = info_Cn_delta_a_Nelson;
end

% Rudder yawing-moment derivative, Cn_delta_r:
% Prefer the input-file value. If missing, use the Nelson rudder estimate.
if isfield(pAV, 'Cn_delta_r') && ~isempty(pAV.Cn_delta_r) && isfinite(pAV.Cn_delta_r)
    Cn_delta_r = pAV.Cn_delta_r;
    src_Cn_delta_r = 'input';
    info_Cn_delta_r = struct();
    info_Cn_delta_r.method = 'supplied directly in pAV.Cn_delta_r';
    info_Cn_delta_r.used_estimate = false;
else
    Cn_delta_r = Cn_delta_r_Nelson;
    src_Cn_delta_r = 'estimated_Nelson_rudder_control';
    info_Cn_delta_r = info_Cn_delta_r_Nelson;
end

if ~isfinite(Cl_delta_a)
    error('AVS_lateral_directional_analysis:CannotEstimateClDeltaA', ...
        'Cl_delta_a is missing and could not be estimated. Reason: %s', ...
        info_Cl_delta_a.reason);
end

if ~isfinite(Cn_delta_a)
    error('AVS_lateral_directional_analysis:CannotEstimateCnDeltaA', ...
        'Cn_delta_a is missing and could not be estimated. Reason: %s', ...
        info_Cn_delta_a.reason);
end

if ~isfinite(Cn_delta_r)
    error('AVS_lateral_directional_analysis:CannotEstimateCnDeltaR', ...
        'Cn_delta_r is missing and could not be estimated. Reason: %s', ...
        info_Cn_delta_r.reason);
end

% Y-force derivatives:
% Use Nelson Table 3.4 forms here instead of defaulting missing terms to zero.
%
% CY_beta remains the active workbook/reference value already read from pAV.
% A Nelson estimate is also computed below for comparison if desired.

requiredCYFields = { ...
    'CL', 'AR', 'sweep_w', ...
    'l_v', 'R_280', 'S_v', ...
    'CL_alpha_v'};

missingCYFields = {};
for k = 1:numel(requiredCYFields)
    f = requiredCYFields{k};
    if ~isfield(pAV,f) || isempty(pAV.(f))
        missingCYFields{end+1} = f; %#ok<AGROW>
    end
end

if ~isempty(missingCYFields)
    error('AVS_lateral_directional_analysis:MissingCYSupportFields', ...
        ['Missing pAV field(s) needed to compute Y-force derivatives ', ...
         'from Nelson Table 3.4: %s'], ...
        strjoin(missingCYFields, ', '));
end

CL           = pAV.CL;
AR           = pAV.AR;
sweep_w      = deg2rad(pAV.sweep_w);
l_v          = pAV.l_v;
R            = pAV.R_280;
S_v          = pAV.S_v;
CL_alpha_v   = pAV.CL_alpha_v;



% Keep workbook/reference CY_beta active for now; compute Nelson estimate separately.
if ~any(isnan([R, S_v, CL_alpha_v]))
    CY_beta_v   = -R * (S_v / S) * CL_alpha_v;
    CY_beta_est = CY_beta_v;
else
    CY_beta_v   = NaN;
    CY_beta_est = NaN;
end

if ~any(isnan([CL, AR, sweep_w]))
    CY_p = CL * ((AR + cos(sweep_w)) / (AR + 4*cos(sweep_w))) * tan(sweep_w);
else
    CY_p = NaN;
end

if ~any(isnan([l_v, CY_beta_v]))
    CY_r = -2 * (l_v / b) * CY_beta_v;
else
    CY_r = NaN;
end

CY_delta_a = 0.0;

if isfield(pAV,'use_zero_CY_delta_r') && pAV.use_zero_CY_delta_r
    CY_delta_r = 0.0;
elseif isfield(pAV,'CY_delta_r') && ~isempty(pAV.CY_delta_r) && ~isnan(pAV.CY_delta_r)
    CY_delta_r = pAV.CY_delta_r;
else
    CY_delta_r = 0.157;
end
% -------------------------------------------------------------------------
% 5) Derived AVS quantities used by the derivative-preparation block
% -------------------------------------------------------------------------
KT2FTPS = 1.68780985710119;

u0_fps = u0 * KT2FTPS;       % ft/s
m      = W / g;              % slugs
qbar   = 0.5 * rho * u0_fps^2; % lbf/ft^2 (consistent in AVS)
QS     = qbar * S;           % lbf
QSb    = qbar * S * b;       % lbf*ft

if u0_fps <= 0
    error('AVS_lateral_directional_analysis:BadSpeed', ...
        'u0 must be positive. Current value: %.6g knots', u0);
end

if S <= 0 || b <= 0 || c_bar <= 0
    error('AVS_lateral_directional_analysis:BadGeometry', ...
        'S, b, and c_bar must all be positive.');
end

if m <= 0
    error('AVS_lateral_directional_analysis:BadMass', ...
        'Weight W and gravity g must imply positive mass.');
end

% -------------------------------------------------------------------------
% 6) Step-3 derivative preparation block
% -------------------------------------------------------------------------
% This section organizes the lateral/directional derivatives into a form
% ready for later state-matrix assembly.
%
% At this stage we distinguish between:
%   A) nondimensional aerodynamic coefficients from the workbook
%   B) dimensional force/moment derivatives in AVS-consistent units
%
% Conventions used here:
%   Y = qbar*S * C_Y
%   L = qbar*S*b * C_l
%   N = qbar*S*b * C_n
%
%   beta, delta_a, delta_r are dimensionless/radians as appropriate
%   p and r derivatives use the standard b/(2*u0) nondimensionalization
%
% Therefore:
%   Y_beta      = qbar*S * CY_beta
%   Y_p         = qbar*S * CY_p        * b/(2*u0)
%   Y_r         = qbar*S * CY_r        * b/(2*u0)
%   L_beta      = qbar*S*b * Cl_beta
%   L_p         = qbar*S*b * Cl_p      * b/(2*u0)
%   L_r         = qbar*S*b * Cl_r      * b/(2*u0)
%   N_beta      = qbar*S*b * Cn_beta
%   N_p         = qbar*S*b * Cn_p      * b/(2*u0)
%   N_r         = qbar*S*b * Cn_r      * b/(2*u0)
%   Y_delta_r   = qbar*S   * CY_delta_r
%   L_delta_a   = qbar*S*b * Cl_delta_a
%   N_delta_a   = qbar*S*b * Cn_delta_a
%   L_delta_r   = qbar*S*b * Cl_delta_r
%   N_delta_r   = qbar*S*b * Cn_delta_r

rateScale = b / (2*u0_fps);

% Side-force derivatives
Y_beta    = QS  * CY_beta;
Y_p       = QS  * CY_p * rateScale;
Y_r       = QS  * CY_r * rateScale;
Y_delta_a = QS  * CY_delta_a;
Y_delta_r = QS  * CY_delta_r;

% Rolling-moment derivatives
L_beta    = QSb * Cl_beta;
L_p       = QSb * Cl_p * rateScale;
L_r       = QSb * Cl_r * rateScale;
L_delta_a = QSb * Cl_delta_a;
L_delta_r = QSb * Cl_delta_r;

% Yawing-moment derivatives
N_beta    = QSb * Cn_beta;
N_p       = QSb * Cn_p * rateScale;
N_r       = QSb * Cn_r * rateScale;
N_delta_a = QSb * Cn_delta_a;
N_delta_r = QSb * Cn_delta_r;

% Normalized-by-mass / inertia forms that are often used later in the
% equations of motion.
Y_beta_over_m    = Y_beta / m;
Y_p_over_m       = Y_p / m;
Y_r_over_m       = Y_r / m;
Y_delta_a_over_m = Y_delta_a / m;
Y_delta_r_over_m = Y_delta_r / m;

L_beta_over_Ix = L_beta / Ix;
L_p_over_Ix    = L_p / Ix;
L_r_over_Ix    = L_r / Ix;
L_da_over_Ix   = L_delta_a / Ix;
L_dr_over_Ix   = L_delta_r / Ix;

N_beta_over_Iz = N_beta / Iz;
N_p_over_Iz    = N_p / Iz;
N_r_over_Iz    = N_r / Iz;
N_da_over_Iz   = N_delta_a / Iz;
N_dr_over_Iz   = N_delta_r / Iz;

% Nelson-style implementation choice for this project stage:
% use Ixz = 0 and do not introduce starred derivatives or inertia-coupling
% determinant bookkeeping here.

% -------------------------------------------------------------------------
% 7) Stage-4 state-space assembly and exact modal extraction
% -------------------------------------------------------------------------
% Nelson-style lateral/directional model used here:
%
%   x_dot = A*x + B*eta
%
%   x   = [Delta_beta; Delta_p; Delta_r; Delta_phi]
%   eta = [Delta_delta_a; Delta_delta_r]
%
% Matrix form implemented according to the uploaded theory notes:
%
%   A = [ Y_beta/u0,  Y_p/u0,  -(1 - Y_r/u0),  g/u0;
%         L_beta,     L_p,     L_r,            0;
%         N_beta,     N_p,     N_r,            0;
%         0,          1,       0,              0 ]
%
%   B = [ 0,             Y_delta_r/u0;
%         L_delta_a,     L_delta_r;
%         N_delta_a,     N_delta_r;
%         0,             0 ]
%
% Important implementation note:
% - In the equations above, u0 is implemented internally as u0_fps.
% - The Y, L, N quantities used below are the normalized forms already
%   prepared in this file:
%       Y_* / m,  L_* / Ix,  N_* / Iz
% - Ixz = 0 is assumed, consistent with the current Nelson-style workflow.
% - If any supporting inputs are NaN, the resulting matrices/eigenvalues
%   will also contain NaN. That is acceptable at the present stage.

A_lat = [ ...
    Y_beta_over_m / u0_fps,    Y_p_over_m / u0_fps,    -(1 - Y_r_over_m / u0_fps),   g / u0_fps; ...
    L_beta_over_Ix,            L_p_over_Ix,            L_r_over_Ix,                   0; ...
    N_beta_over_Iz,            N_p_over_Iz,            N_r_over_Iz,                   0; ...
    0,                         1,                      0,                             0 ...
    ];

B_lat = [ ...
    0,                         Y_delta_r_over_m / u0_fps; ...
    L_da_over_Ix,              L_dr_over_Ix; ...
    N_da_over_Iz,              N_dr_over_Iz; ...
    0,                         0 ...
    ];

eig_lat_exact = NaN(4,1);
roll_mode_exact   = NaN;
spiral_mode_exact = NaN;
dutch_mode_exact  = [NaN; NaN];

if all(isfinite(A_lat(:)))
    eig_lat_exact = eig(A_lat);

    isRealMode = abs(imag(eig_lat_exact)) <= 1.0e-10;
isComplexMode = abs(imag(eig_lat_exact)) > 1.0e-10;


realModes = eig_lat_exact(isRealMode);
    if numel(realModes) >= 1
        [~, idxRoll] = max(abs(real(realModes)));
        roll_mode_exact = realModes(idxRoll);

        [~, idxSpiral] = min(abs(real(realModes)));
        spiral_mode_exact = realModes(idxSpiral);
    end

    if nnz(isComplexMode) >= 2
            complexModes = eig_lat_exact(isComplexMode);
        [~, orderComplex] = sort(abs(imag(complexModes)), 'descend');
        complexModes = complexModes(orderComplex);
        dutch_mode_exact = complexModes(1:2);
    end
end

% -------------------------------------------------------------------------
% 8) Stage-5 approximate modal relations from the uploaded notes
% -------------------------------------------------------------------------
% 5.40:  Delta_r_dot + (L_r*N_beta - L_beta*N_r)/L_beta * Delta_r = 0
% 5.41:  lambda_spiral = (L_beta*N_r - L_r*N_beta) / L_beta
% 5.44:  lambda_roll = L_p
% 5.46:  lambda^2 - ((Y_beta + u0*N_r)/u0) * lambda
%               + (Y_beta*N_r - N_beta*Y_r + u0*N_beta)/u0 = 0
% 5.47:  wn_DR = sqrt((Y_beta*N_r - N_beta*Y_r + u0*N_beta)/u0)
% 5.48:  zeta  = -(1/(2*wn_DR)) * ((Y_beta + u0*N_r)/u0)
%
% These are kept explicitly approximate and are intended only as side notes.

% 8.1 Roll mode approximation [5.44]
lambda_roll_approx = L_p_over_Ix;

if isfinite(lambda_roll_approx) && lambda_roll_approx ~= 0
    tau_roll_approx = -1 / lambda_roll_approx;
else
    tau_roll_approx = NaN;
end

% 8.2 Spiral mode approximation [5.41]
num_spiral_approx = L_beta_over_Ix * N_r_over_Iz - L_r_over_Ix * N_beta_over_Iz;
den_spiral_approx = L_beta_over_Ix;

if isfinite(num_spiral_approx) && isfinite(den_spiral_approx) && den_spiral_approx ~= 0
    lambda_spiral_approx = num_spiral_approx / den_spiral_approx;
else
    lambda_spiral_approx = NaN;
end

% 8.3 Dutch-roll approximation [5.46]-[5.48]
a1_dutch = (Y_beta_over_m + u0_fps * N_r_over_Iz) / u0_fps;
a0_dutch = (Y_beta_over_m * N_r_over_Iz - N_beta_over_Iz * Y_r_over_m + u0_fps * N_beta_over_Iz) / u0_fps;

eig_dutch_approx = [NaN; NaN];
wn_dutch_approx  = NaN;
zeta_dutch_approx = NaN;

if all(isfinite([a1_dutch, a0_dutch]))
    eig_dutch_approx = roots([1, -a1_dutch, a0_dutch]);

    if a0_dutch >= 0
        wn_dutch_approx = sqrt(a0_dutch);
    end

    if isfinite(wn_dutch_approx) && wn_dutch_approx > 0
        zeta_dutch_approx = -(1 / (2 * wn_dutch_approx)) * a1_dutch;
    end
end

% -------------------------------------------------------------------------
% 9) Package outputs
% -------------------------------------------------------------------------
out = struct();

out.meta.file = mfilename;
out.meta.stage_completed = 'Steps 1-5: interface, derivative preparation, state-space, exact modes, approximations';
out.meta.units = 'AVS';
out.meta.aircraft = pAV.aircraft;
out.meta.notes = [ ...
    "Stage 4 implemented using the 4-state lateral model from Eq. [5.28].", ...
    "Exact roots are obtained from eig(A_lat) and correspond to the quartic characteristic relation.", ...
    "Stage 5 approximate roll, spiral, and Dutch-roll relations are included only as side-note approximations.", ...
    "NaN support quantities in the current input file are allowed to propagate into matrices and modal results at this stage." ...
    ];

out.assumptions = struct();
out.assumptions.input_source = 'AVS_input_lateral_NAVION_clean.m';
out.assumptions.beta_based_bookkeeping = true;
out.assumptions.CY_p = CY_p;
out.assumptions.CY_r = CY_r;
out.assumptions.CY_delta_a = CY_delta_a;
out.assumptions.CY_delta_r = CY_delta_r;
out.assumptions.theta0 = theta0;
out.assumptions.phi0 = phi0;
out.assumptions.no_state_matrix_yet = false;
out.assumptions.no_mode_classification_yet = false;

out.flight_condition = struct();
out.flight_condition.u0 = u0;
out.flight_condition.u0_fps = u0_fps;
out.flight_condition.rho = rho;
out.flight_condition.W = W;
out.flight_condition.m = m;
out.flight_condition.qbar = qbar;
out.flight_condition.g = g;

out.geometry = struct();
out.geometry.S = S;
out.geometry.b = b;
out.geometry.c_bar = c_bar;

out.inertia = struct();
out.inertia.Ix = Ix;
out.inertia.Iz = Iz;
out.inertia.Ixz = Ixz;
out.inertia.Ixz_assumed_zero = (Ixz == 0);

out.nondim = struct();
out.nondim.CY_beta = CY_beta;
out.nondim.CY_beta_est = CY_beta_est;
out.nondim.CY_p = CY_p;
out.nondim.CY_r = CY_r;
out.nondim.CY_delta_a = CY_delta_a;
out.nondim.CY_delta_r = CY_delta_r;
out.nondim.Cl_beta = Cl_beta;
out.nondim.Cl_p = Cl_p;
out.nondim.Cl_r = Cl_r;
out.nondim.Cl_delta_a = Cl_delta_a;
out.nondim.Cl_delta_r = Cl_delta_r;
out.nondim.Cn_beta = Cn_beta;
out.nondim.Cn_p = Cn_p;
out.nondim.Cn_r = Cn_r;
out.nondim.Cn_delta_a = Cn_delta_a;
out.nondim.Cn_delta_r = Cn_delta_r;
out.derivative_sources = struct();

out.derivative_sources.Cl_delta_a = struct();
out.derivative_sources.Cl_delta_a.source = src_Cl_delta_a;
out.derivative_sources.Cl_delta_a.value = Cl_delta_a;
out.derivative_sources.Cl_delta_a.info = info_Cl_delta_a;

out.derivative_sources.Cn_delta_a = struct();
out.derivative_sources.Cn_delta_a.source = src_Cn_delta_a;
out.derivative_sources.Cn_delta_a.value = Cn_delta_a;
out.derivative_sources.Cn_delta_a.info = info_Cn_delta_a;

out.derivative_sources.Cn_delta_r = struct();
out.derivative_sources.Cn_delta_r.source = src_Cn_delta_r;
out.derivative_sources.Cn_delta_r.value = Cn_delta_r;
out.derivative_sources.Cn_delta_r.info = info_Cn_delta_r;

% Nelson-calculated values for comparison/reporting.
% These are not necessarily the values used in the model. The active values
% are stored in out.nondim and their source is stored in out.derivative_sources.
out.nelson_estimates = struct();

out.nelson_estimates.Cl_delta_a = struct();
out.nelson_estimates.Cl_delta_a.value = Cl_delta_a_Nelson;
out.nelson_estimates.Cl_delta_a.source = 'calculated_Nelson_Eq_2_96_not_input';
out.nelson_estimates.Cl_delta_a.info = info_Cl_delta_a_Nelson;

out.nelson_estimates.Cn_delta_a = struct();
out.nelson_estimates.Cn_delta_a.value = Cn_delta_a_Nelson;
out.nelson_estimates.Cn_delta_a.source = 'calculated_Nelson_Table_3_4_Fig_3_12_not_input';
out.nelson_estimates.Cn_delta_a.info = info_Cn_delta_a_Nelson;

out.nelson_estimates.Cn_delta_r = struct();
out.nelson_estimates.Cn_delta_r.value = Cn_delta_r_Nelson;
out.nelson_estimates.Cn_delta_r.source = 'calculated_Nelson_rudder_control_not_input';
out.nelson_estimates.Cn_delta_r.info = info_Cn_delta_r_Nelson;

% Aileron control power from Nelson Eq. [2.96].
% With CL_alpha_w in 1/rad, this derivative is per radian of aileron deflection.
out.control_power = struct();
out.control_power.aileron = struct();
out.control_power.aileron.Cl_delta_a_per_rad = Cl_delta_a_Nelson;
out.control_power.aileron.Cl_delta_a_per_deg = Cl_delta_a_Nelson * pi/180;
out.control_power.aileron.source = 'calculated_Nelson_Eq_2_96_not_input';
out.control_power.aileron.info = info_Cl_delta_a_Nelson;

out.scale = struct();
out.scale.rateScale = rateScale;
out.scale.QS = QS;
out.scale.QSb = QSb;

out.dimensional = struct();
out.dimensional.Y_beta = Y_beta;
out.dimensional.Y_p = Y_p;
out.dimensional.Y_r = Y_r;
out.dimensional.Y_delta_a = Y_delta_a;
out.dimensional.Y_delta_r = Y_delta_r;
out.dimensional.L_beta = L_beta;
out.dimensional.L_p = L_p;
out.dimensional.L_r = L_r;
out.dimensional.L_delta_a = L_delta_a;
out.dimensional.L_delta_r = L_delta_r;
out.dimensional.N_beta = N_beta;
out.dimensional.N_p = N_p;
out.dimensional.N_r = N_r;
out.dimensional.N_delta_a = N_delta_a;
out.dimensional.N_delta_r = N_delta_r;

out.normalized = struct();
out.normalized.Y_beta_over_m = Y_beta_over_m;
out.normalized.Y_p_over_m = Y_p_over_m;
out.normalized.Y_r_over_m = Y_r_over_m;
out.normalized.Y_delta_a_over_m = Y_delta_a_over_m;
out.normalized.Y_delta_r_over_m = Y_delta_r_over_m;
out.normalized.L_beta_over_Ix = L_beta_over_Ix;
out.normalized.L_p_over_Ix = L_p_over_Ix;
out.normalized.L_r_over_Ix = L_r_over_Ix;
out.normalized.L_da_over_Ix = L_da_over_Ix;
out.normalized.L_dr_over_Ix = L_dr_over_Ix;
out.normalized.N_beta_over_Iz = N_beta_over_Iz;
out.normalized.N_p_over_Iz = N_p_over_Iz;
out.normalized.N_r_over_Iz = N_r_over_Iz;
out.normalized.N_da_over_Iz = N_da_over_Iz;
out.normalized.N_dr_over_Iz = N_dr_over_Iz;

out.state_space = struct();
out.state_space.state_vector = {'Delta_beta','Delta_p','Delta_r','Delta_phi'};
out.state_space.control_vector = {'Delta_delta_a','Delta_delta_r'};
out.state_space.A_lat = A_lat;
out.state_space.B_lat = B_lat;

out.modes_exact = struct();
out.modes_exact.eigenvalues = eig_lat_exact;
out.modes_exact.roll_mode = roll_mode_exact;
out.modes_exact.spiral_mode = spiral_mode_exact;
out.modes_exact.dutch_mode = dutch_mode_exact;

out.approx = struct();

out.approx.roll = struct();
out.approx.roll.lambda = lambda_roll_approx;
out.approx.roll.tau = tau_roll_approx;

out.approx.spiral = struct();
out.approx.spiral.lambda = lambda_spiral_approx;
out.approx.spiral.numerator = num_spiral_approx;
out.approx.spiral.denominator = den_spiral_approx;

out.approx.dutch = struct();
out.approx.dutch.characteristic_polynomial = [1, -a1_dutch, a0_dutch];
out.approx.dutch.eigenvalues = eig_dutch_approx;
out.approx.dutch.wn = wn_dutch_approx;
out.approx.dutch.zeta = zeta_dutch_approx;

% -------------------------------------------------------------------------
% 10) Static stability report
% -------------------------------------------------------------------------

% Directional static stability (Chapter 2.6)
is_directionally_stable = isfinite(Cn_beta) && (Cn_beta > 0);

% Roll static stability / dihedral effect (Chapter 2.8)
is_roll_stable = isfinite(Cl_beta) && (Cl_beta < 0);

% Spiral mode stability (Eq. [5.42]) with sign-condition check
spiral_sign_pattern_ok = isfinite(L_beta) && isfinite(N_r) && isfinite(L_r) && isfinite(N_beta) ...
                      && (L_beta < 0) && (N_r < 0) && (L_r > 0) && (N_beta > 0);

spiral_expr = L_beta*N_r - L_r*N_beta;

if isfinite(spiral_expr)
    if spiral_expr > 0
        spiral_result_text = 'STABLE';
    elseif spiral_expr < 0
        spiral_result_text = 'UNSTABLE';
    else
        spiral_result_text = 'NEUTRAL / MARGINAL';
    end
else
    spiral_result_text = 'UNDETERMINED';
end

if spiral_sign_pattern_ok
    spiral_note_text = 'Required sign pattern satisfied: result may be used with confidence.';
else
    spiral_note_text = ['Required sign pattern NOT satisfied: result is shown, ', ...
                        'but should be treated with caution.'];
end

out.static_stability = struct();

out.static_stability.directional = struct();
out.static_stability.directional.condition = 'Cn_beta > 0';
out.static_stability.directional.value = Cn_beta;
out.static_stability.directional.is_stable = is_directionally_stable;

out.static_stability.roll = struct();
out.static_stability.roll.condition = 'Cl_beta < 0';
out.static_stability.roll.value = Cl_beta;
out.static_stability.roll.is_stable = is_roll_stable;

out.static_stability.spiral = struct();
out.static_stability.spiral.condition = 'L_beta*N_r - L_r*N_beta > 0';
out.static_stability.spiral.expression_value = spiral_expr;
out.static_stability.spiral.L_beta = L_beta;
out.static_stability.spiral.N_r = N_r;
out.static_stability.spiral.L_r = L_r;
out.static_stability.spiral.N_beta = N_beta;
out.static_stability.spiral.sign_pattern_ok = spiral_sign_pattern_ok;
out.static_stability.spiral.result_text = spiral_result_text;
out.static_stability.spiral.note = spiral_note_text;

fprintf('\n---- Lateral/Directional Stability Report ----\n');

fprintf('\nDirectional Stability \n');
fprintf('  Condition: Cn_beta > 0\n');
if is_directionally_stable
    fprintf('  Cn_beta = % .6f  -->  STABLE\n', Cn_beta);
else
    fprintf('  Cn_beta = % .6f  -->  UNSTABLE\n', Cn_beta);
end

fprintf('\nRoll Stability \n');
fprintf('  Condition: Cl_beta < 0\n');
if is_roll_stable
    fprintf('  Cl_beta = % .6f  -->  STABLE\n', Cl_beta);
else
    fprintf('  Cl_beta = % .6f  -->  UNSTABLE\n', Cl_beta);
end

fprintf('\nSpiral Mode Stability \n');
fprintf('  Condition used: L_beta*N_r - L_r*N_beta > 0\n');

if isfinite(spiral_expr)
    if spiral_expr > 0
        fprintf('  L_beta*N_r - L_r*N_beta = % .6f  -->  STABLE\n', spiral_expr);
    elseif spiral_expr < 0
        fprintf('  L_beta*N_r - L_r*N_beta = % .6f  -->  UNSTABLE\n', spiral_expr);
    else
        fprintf('  L_beta*N_r - L_r*N_beta = % .6f  -->  NEUTRAL / MARGINAL\n', spiral_expr);
    end
else
    fprintf('  L_beta*N_r - L_r*N_beta = NaN  -->  UNDETERMINED\n');
end

if spiral_sign_pattern_ok
    fprintf('  Note: Required sign pattern satisfied: L_beta<0, N_r<0, L_r>0, N_beta>0\n');
else
    fprintf('  Note: Required sign pattern NOT satisfied, so THIS RESULT SHOULD BE TREATED WITH CAUTION\n');
end

end

function val = avs_get_numeric_field(pAV, fieldName, defaultValue)
%AVS_GET_NUMERIC_FIELD
% Return pAV.(fieldName) if it exists, is numeric, scalar, and finite.
% Otherwise return defaultValue.

    if nargin < 3
        defaultValue = NaN;
    end

    val = defaultValue;

    if ~isfield(pAV, fieldName)
        return;
    end

    candidate = pAV.(fieldName);

    if isempty(candidate) || ~isnumeric(candidate) || ~isscalar(candidate)
        return;
    end

    if ~isfinite(candidate)
        return;
    end

    val = candidate;
end

function tau = avs_tau_fig_2_21(x)
%AVS_TAU_FIG_2_21
% Digitized Nelson Fig. 2.21 flap/control effectiveness factor.
%
% tau = min(1.0251*x^0.5932, 0.80)
%
% For aileron:
%   x may be the aileron chord ratio c_a/c when that is the available
%   sectional ratio, as in Nelson's NAVION example.
%
% For rudder:
%   x = S_r / S_v

    if nargin < 1 || isempty(x) || ~isnumeric(x) || ~isscalar(x) || ~isfinite(x) || x <= 0
        tau = NaN;
        return;
    end

    tau = min(1.0251 * x.^0.5932, 0.80);
end

function [Cl_delta_a_est, info] = avs_estimate_Cl_delta_a_Nelson(pAV)
%AVS_ESTIMATE_CL_DELTA_A_NELSON
% Estimate aileron rolling-moment control derivative Cl_delta_a using
% Nelson Eq. [2.96] and digitized Fig. 2.21.

    info = struct();
    info.method = 'Nelson Eq. [2.96] with digitized Fig. 2.21';
    info.used_estimate = true;
    info.reason = '';

    S          = avs_get_numeric_field(pAV, 'S');
    b          = avs_get_numeric_field(pAV, 'b');
    CL_alpha_w = avs_get_numeric_field(pAV, 'CL_alpha_w');
    c_root     = avs_get_numeric_field(pAV, 'c_root');
    lambda     = avs_get_numeric_field(pAV, 'TaperRatio');
    y1         = avs_get_numeric_field(pAV, 'y1');
    y2         = avs_get_numeric_field(pAV, 'y2');

    tau_a = avs_get_numeric_field(pAV, 'tau_a');
    if isfinite(tau_a)
        info.tau_source = 'pAV.tau_a';
        info.x_fig_2_21 = NaN;
    else
        ca_c = avs_get_numeric_field(pAV, 'ca_c');
        tau_a = avs_tau_fig_2_21(ca_c);
        info.tau_source = 'pAV.ca_c through digitized Nelson Fig. 2.21';
        info.x_fig_2_21 = ca_c;
    end

    required = [S, b, CL_alpha_w, c_root, lambda, y1, y2, tau_a];

    if any(~isfinite(required))
        Cl_delta_a_est = NaN;
        info.reason = ['Missing one or more fields needed for Cl_delta_a estimate: ', ...
                       'S, b, CL_alpha_w, c_root, TaperRatio, y1, y2, and tau_a or ca_c.'];
        return;
    end

    if S <= 0 || b <= 0 || c_root <= 0 || y1 < 0 || y2 <= y1
        Cl_delta_a_est = NaN;
        info.reason = 'Invalid aileron/wing geometry for Cl_delta_a estimate.';
        return;
    end

    % Tapered-wing chord model:
    % c(y) = c_root * [1 - 2*(1 - lambda)*y/b]
    %
    % Nelson Eq. [2.96]:
    % Cl_delta_a = (2*CL_alpha_w*tau_a/(S*b)) * integral_y1^y2 c(y)*y dy

    integral_cy = c_root * ...
        (0.5 * (y2^2 - y1^2) ...
        - (2 * (1 - lambda) / (3*b)) * (y2^3 - y1^3));

    Cl_delta_a_est = (2 * CL_alpha_w * tau_a / (S*b)) * integral_cy;

    info.reason = 'Cl_delta_a estimated successfully.';
    info.tau_a = tau_a;
    info.integral_cy = integral_cy;
end

function [Cn_delta_r_est, info] = avs_estimate_Cn_delta_r_Nelson(pAV)
%AVS_ESTIMATE_CN_DELTA_R_NELSON
% Estimate rudder yawing-moment control derivative Cn_delta_r.
%
% Formula used:
%   Cn_delta_r = -CL_alpha_v * eta_v * tau_r * V_v
%
% where:
%   V_v = S_v*l_v/(S*b)
%
% tau_r is obtained from digitized Nelson Fig. 2.21 using:
%   x = S_r/S_v

    info = struct();
    info.method = 'Nelson rudder control effectiveness with digitized Fig. 2.21';
    info.used_estimate = true;
    info.reason = '';

    S = avs_get_numeric_field(pAV, 'S');
    b = avs_get_numeric_field(pAV, 'b');

    S_v = avs_get_numeric_field(pAV, 'S_v');
    if ~isfinite(S_v)
        S_v = avs_get_numeric_field(pAV, 'Sv');
    end

    l_v = avs_get_numeric_field(pAV, 'l_v');
    if ~isfinite(l_v)
        l_v = avs_get_numeric_field(pAV, 'lv');
    end

    CL_alpha_v = avs_get_numeric_field(pAV, 'CL_alpha_v');
    if ~isfinite(CL_alpha_v)
        CL_alpha_v = avs_get_numeric_field(pAV, 'Cla_v');
    end

    eta_v = avs_get_numeric_field(pAV, 'eta_v');

    if isfinite(eta_v)
        info.eta_v_source = 'pAV.eta_v';
    else
        % Assumption for rudder control derivative only:
        % eta_v is the dynamic-pressure ratio at the vertical tail.
        % If no aircraft-specific value is available, eta_v = 1 is used as a
        % preliminary conventional-aircraft approximation. Treat with caution,
        % especially for configurations with strong wake, propwash, or high-AoA effects.
        eta_v = 1.0;
        info.eta_v_source = 'assumed eta_v = 1.0 for Cn_delta_r only';
    end

    tau_r = avs_get_numeric_field(pAV, 'tau_r');
    if isfinite(tau_r)
        info.tau_source = 'pAV.tau_r';
        info.x_fig_2_21 = NaN;
    else
        Sr_Sv = avs_get_numeric_field(pAV, 'Sr_Sv');
        tau_r = avs_tau_fig_2_21(Sr_Sv);
        info.tau_source = 'pAV.Sr_Sv through digitized Nelson Fig. 2.21';
        info.x_fig_2_21 = Sr_Sv;
    end

    required = [S, b, S_v, l_v, CL_alpha_v, eta_v, tau_r];

    if any(~isfinite(required))
        Cn_delta_r_est = NaN;
        info.reason = ['Missing one or more fields needed for Cn_delta_r estimate: ', ...
                       'S, b, S_v/Sv, l_v/lv, CL_alpha_v/Cla_v, eta_v, and tau_r or Sr_Sv.'];
        return;
    end

    if S <= 0 || b <= 0 || S_v <= 0 || l_v <= 0 || CL_alpha_v <= 0 || eta_v <= 0
        Cn_delta_r_est = NaN;
        info.reason = 'Invalid vertical-tail/rudder geometry or aerodynamic data for Cn_delta_r estimate.';
        return;
    end

    V_v = S_v * l_v / (S * b);

    Cn_delta_r_est = -CL_alpha_v * eta_v * tau_r * V_v;

    info.reason = 'Cn_delta_r estimated successfully.';
    info.S_v = S_v;
    info.l_v = l_v;
    info.CL_alpha_v = CL_alpha_v;
    info.eta_v = eta_v;
    info.tau_r = tau_r;
    info.V_v = V_v;
end

function [Cn_delta_a_est, info] = avs_estimate_Cn_delta_a_Nelson(pAV, Cl_delta_a_for_est)
%AVS_ESTIMATE_CN_DELTA_A_NELSON
% Estimate aileron yawing-moment derivative Cn_delta_a.
%
% Nelson Table 3.4:
%   Cn_delta_a = 2*K*CL0*Cl_delta_a
%
% K is obtained from digitized Nelson Fig. 3.12.
% The Fig. 3.12 horizontal-axis variable is:
%   eta = y1/(b/2)
%
% This eta is NOT the same as eta_v.

    info = struct();
    info.method = 'Nelson Table 3.4 with K from digitized Fig. 3.12';
    info.used_estimate = true;
    info.reason = '';

    if nargin < 2 || isempty(Cl_delta_a_for_est) || ~isnumeric(Cl_delta_a_for_est) ...
            || ~isscalar(Cl_delta_a_for_est) || ~isfinite(Cl_delta_a_for_est)
        Cl_delta_a_for_est = NaN;
    end

    CL0 = avs_get_numeric_field(pAV, 'CL0');
    if ~isfinite(CL0)
        CL0 = avs_get_numeric_field(pAV, 'CL');
    end

    AR = avs_get_numeric_field(pAV, 'AR');
    if ~isfinite(AR)
        b_tmp = avs_get_numeric_field(pAV, 'b');
        S_tmp = avs_get_numeric_field(pAV, 'S');
        if isfinite(b_tmp) && isfinite(S_tmp) && S_tmp > 0
            AR = b_tmp^2 / S_tmp;
        end
    end

    b = avs_get_numeric_field(pAV, 'b');
    y1 = avs_get_numeric_field(pAV, 'y1');

    if isfinite(b) && isfinite(y1) && b > 0
        eta_aileron = y1 / (b/2);
    else
        eta_aileron = NaN;
    end

    K_direct = avs_get_numeric_field(pAV, 'K_fig_3_12');

    if isfinite(K_direct)
        K = K_direct;
        info.K_source = 'pAV.K_fig_3_12';
        csvPath = '';
    else
        csvPath = avs_resolve_fig_3_12_csv_path(pAV);
        [K, infoK] = avs_interp_K_fig_3_12(csvPath, eta_aileron, AR);
        info.K_source = 'digitized Nelson Fig. 3.12 CSV';
        info.K_interpolation = infoK;
    end

    required = [CL0, AR, eta_aileron, K, Cl_delta_a_for_est];

    if any(~isfinite(required))
        Cn_delta_a_est = NaN;
        info.reason = ['Missing one or more fields needed for Cn_delta_a estimate: ', ...
                       'CL0 or CL, AR or b and S, y1, b, K from Fig. 3.12, and Cl_delta_a.'];
        info.CL0 = CL0;
        info.AR = AR;
        info.eta_aileron = eta_aileron;
        info.K = K;
        info.Cl_delta_a_used = Cl_delta_a_for_est;
        info.csvPath = csvPath;
        return;
    end

    % Nelson Table 3.4:
    % Cn_delta_a = 2*K*CL0*Cl_delta_a
    %
    % K is normally negative for the Fig. 3.12 range, so this usually gives
    % adverse yaw for positive aileron rolling control power.
    Cn_delta_a_est = 2 * K * CL0 * Cl_delta_a_for_est;

    info.reason = 'Cn_delta_a estimated successfully.';
    info.CL0 = CL0;
    info.AR = AR;
    info.eta_aileron = eta_aileron;
    info.K = K;
    info.Cl_delta_a_used = Cl_delta_a_for_est;
    info.csvPath = csvPath;
end

function csvPath = avs_resolve_fig_3_12_csv_path(pAV)
%AVS_RESOLVE_FIG_3_12_CSV_PATH
% Resolve the file path for the digitized Nelson Fig. 3.12 CSV.
%
% Search order:
%   1) pAV.fig_3_12_csv, if it is already a valid full or relative path
%   2) pAV.digitized_figures_folder/defaultName
%   3) pAV.project_folder/Digitalized Figs/defaultName
%   4) folder containing this analysis file/Digitalized Figs/defaultName
%   5) folder containing this analysis file/defaultName
%   6) MATLAB current folder/Digitalized Figs/defaultName
%   7) MATLAB current folder/defaultName

    defaultName = 'fig3_12_digitized_K_vs_eta_lambda_0_5.csv';
    csvPath = defaultName;

    % 1) Input-provided path
    if isfield(pAV, 'fig_3_12_csv') && ~isempty(pAV.fig_3_12_csv)
        if ischar(pAV.fig_3_12_csv)
            csvPath = pAV.fig_3_12_csv;
        elseif isstring(pAV.fig_3_12_csv)
            csvPath = char(pAV.fig_3_12_csv);
        end
    end

    if isfile(csvPath)
        return;
    end

    % 2) Explicit digitized-figures folder from input file
    if isfield(pAV, 'digitized_figures_folder') && ~isempty(pAV.digitized_figures_folder)
        figFolder = char(pAV.digitized_figures_folder);
        candidatePath = fullfile(figFolder, defaultName);
        if isfile(candidatePath)
            csvPath = candidatePath;
            return;
        end
    end

    % 3) Project folder from input file
    if isfield(pAV, 'project_folder') && ~isempty(pAV.project_folder)
        projectFolder = char(pAV.project_folder);

        candidatePath = fullfile(projectFolder, 'Digitalized Figs', defaultName);
        if isfile(candidatePath)
            csvPath = candidatePath;
            return;
        end

        candidatePath = fullfile(projectFolder, defaultName);
        if isfile(candidatePath)
            csvPath = candidatePath;
            return;
        end
    end

    % 4-5) Folder containing this analysis function
    analysisFolder = fileparts(mfilename('fullpath'));

    candidatePath = fullfile(analysisFolder, 'Digitalized Figs', defaultName);
    if isfile(candidatePath)
        csvPath = candidatePath;
        return;
    end

    candidatePath = fullfile(analysisFolder, defaultName);
    if isfile(candidatePath)
        csvPath = candidatePath;
        return;
    end

    % 6-7) MATLAB current folder
    candidatePath = fullfile(pwd, 'Digitalized Figs', defaultName);
    if isfile(candidatePath)
        csvPath = candidatePath;
        return;
    end

    candidatePath = fullfile(pwd, defaultName);
    if isfile(candidatePath)
        csvPath = candidatePath;
        return;
    end

    % If the file is not found, keep csvPath as originally requested.
    % The interpolation helper will return NaN and store the reason.
end

function [K, info] = avs_interp_K_fig_3_12(csvPath, eta_aileron, AR)
%AVS_INTERP_K_FIG_3_12
% Interpolate K from digitized Nelson Fig. 3.12 CSV.
%
% Expected CSV format:
%   eta,K_AR4,K_AR6,K_AR8
%
% The uploaded CSV corresponds to lambda = 0.5.

    info = struct();
    info.reason = '';
    info.csvPath = csvPath;
    info.lambda_dataset = 0.5;
    info.eta_aileron = eta_aileron;
    info.AR = AR;

    K = NaN;

    if nargin < 3 || ~isfinite(eta_aileron) || ~isfinite(AR)
        info.reason = 'eta_aileron and/or AR are not finite.';
        return;
    end

    if ~isfile(csvPath)
    info.reason = sprintf('Fig. 3.12 CSV file was not found at: %s', csvPath);
    return;
    end

    T = readtable(csvPath);
    varNames = T.Properties.VariableNames;

    if numel(varNames) < 2
        info.reason = 'Fig. 3.12 CSV does not contain enough columns.';
        return;
    end

    etaData = T.(varNames{1});

    AR_data = [];
    K_data = [];

    for j = 2:numel(varNames)
        token = regexp(varNames{j}, 'AR([0-9]+(?:p[0-9]+)?|[0-9]+(?:_[0-9]+)?)', 'tokens', 'once');

        if isempty(token)
            token = regexp(varNames{j}, 'AR([0-9]+)', 'tokens', 'once');
        end

        if isempty(token)
            continue;
        end

        arText = token{1};
        arText = strrep(arText, 'p', '.');
        arText = strrep(arText, '_', '.');

        arValue = str2double(arText);

        if ~isfinite(arValue)
            continue;
        end

        AR_data(end+1) = arValue; %#ok<AGROW>
        K_data(:,end+1) = T.(varNames{j}); %#ok<AGROW>
    end

    if isempty(AR_data)
        info.reason = 'Could not identify AR columns in Fig. 3.12 CSV.';
        return;
    end

    [AR_data, order] = sort(AR_data);
    K_data = K_data(:,order);

    etaMin = min(etaData);
    etaMax = max(etaData);
    ARMin = min(AR_data);
    ARMax = max(AR_data);

    info.eta_range = [etaMin, etaMax];
    info.AR_range = [ARMin, ARMax];

    if eta_aileron < etaMin || eta_aileron > etaMax
        info.reason = 'eta_aileron is outside the digitized Fig. 3.12 eta range.';
        return;
    end

    if AR < ARMin || AR > ARMax
        info.reason = 'AR is outside the digitized Fig. 3.12 AR range.';
        return;
    end

    K_vs_AR = NaN(size(AR_data));

    for j = 1:numel(AR_data)
        K_vs_AR(j) = interp1(etaData, K_data(:,j), eta_aileron, 'linear');
    end

    K = interp1(AR_data, K_vs_AR, AR, 'linear');

    if isfinite(K)
        info.reason = 'K interpolated successfully from digitized Fig. 3.12.';
        info.AR_data = AR_data;
        info.K_vs_AR_at_eta = K_vs_AR;
        info.K = K;
    else
        info.reason = 'Interpolation returned NaN.';
    end
end