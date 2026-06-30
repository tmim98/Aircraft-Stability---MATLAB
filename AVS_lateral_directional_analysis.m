function out = AVS_lateral_directional_analysis(pAV)
% AVS_LATERAL_DIRECTIONAL_ANALYSIS
% Lateral/directional analysis core for the aircraft stability workflow.
%
% This version implements:
%   1) interface and assumptions
%   2) input unpacking / validation / bookkeeping
%   3) derivative preparation in AVS-consistent units
%   4) lateral-directional state-space assembly
%   5) exact eigenvalue and modal classification
%   6) approximate roll, spiral, and Dutch-roll calculations
%
% Intended data source:
%   pAV struct supplied by the current aircraft input script.
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
%   - Workbook/reference derivatives supplied in pAV are used where selected.
%   - Nelson-style geometry-based estimates are also calculated and stored
%     separately for comparison/documentation.
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
% Main output groups:
%   out.flight_condition, out.geometry, out.inertia
%   out.nondim, out.derivative_sources, out.nelson_estimates
%   out.dimensional, out.normalized
%   out.state_space, out.modes_exact, out.approx
%   out.static_stability
%
% -------------------------------------------------------------------------
% 1) Load / validate inputs
% -------------------------------------------------------------------------
if nargin < 1 || isempty(pAV)
    run('AVS_input_lateral_current.m');
end

if ~exist('pAV','var') || ~isstruct(pAV)
    error('AVS_lateral_directional_analysis:MissingInput', ...
        ['Input struct pAV was not supplied and could not be created by ', ...
         'running AVS_input_lateral_current.m.']);
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

% Current convention note:
% - beta is treated as the primary lateral translational perturbation state
%   for derivative bookkeeping and for the first state in A_lat.
% - Rate derivatives with respect to p and r use the standard nondimensional
%   forms based on b/(2*u0).
% - The assembled lateral state-space model uses the state vector
%   [Delta_beta; Delta_p; Delta_r; Delta_phi].

% -------------------------------------------------------------------------
% 3) Required-field validation
% -------------------------------------------------------------------------
requiredFields = {
    'u0', 'rho', 'W', ...
    'S', 'b', 'c_bar', ...
    'Ix', 'Iz', 'Ixz', ...
    'CY_beta', 'Cl_beta', ...
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

% Directional-stability derivative, Cn_beta:
% Always calculate the Nelson estimate for reporting/comparison.
% If pAV.Cn_beta exists, the input value remains the active value.
[Cn_beta_Nelson, info_Cn_beta_Nelson] = avs_estimate_Cn_beta_Nelson(pAV);

if isfield(pAV, 'Cn_beta') && ~isempty(pAV.Cn_beta) && isfinite(pAV.Cn_beta)
    Cn_beta = pAV.Cn_beta;
    src_Cn_beta = 'input';
    info_Cn_beta = struct();
    info_Cn_beta.method = 'supplied directly in pAV.Cn_beta';
    info_Cn_beta.used_estimate = false;
else
    Cn_beta = Cn_beta_Nelson;
    src_Cn_beta = 'estimated_Nelson_Eq_2_73_Fig_2_29_Fig_2_30_plus_vertical_tail';
    info_Cn_beta = info_Cn_beta_Nelson;
end

% Rolling-moment derivative due to sideslip, Cl_beta:
% Always calculate the Nelson Fig. 3.11 estimate for reporting/comparison.
[Cl_beta_Nelson, info_Cl_beta_Nelson] = avs_estimate_Cl_beta_Nelson(pAV);

% Prefer the input-file value. If missing, use the Nelson Fig. 3.11 estimate.
if isfield(pAV, 'Cl_beta') && ~isempty(pAV.Cl_beta) && isfinite(pAV.Cl_beta)
    Cl_beta = pAV.Cl_beta;
    src_Cl_beta = 'input';
    info_Cl_beta = struct();
    info_Cl_beta.method = 'supplied directly in pAV.Cl_beta';
    info_Cl_beta.used_estimate = false;
else
    Cl_beta = Cl_beta_Nelson;
    src_Cl_beta = 'estimated_Nelson_Fig_3_11';
    info_Cl_beta = info_Cl_beta_Nelson;
end

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

if ~isfinite(Cl_beta)
    error('AVS_lateral_directional_analysis:CannotEstimateClBeta', ...
        'Cl_beta is missing and could not be estimated. Reason: %s', ...
        info_Cl_beta.reason);
end
if ~isfinite(Cn_beta)
    error('AVS_lateral_directional_analysis:CannotEstimateCnBeta', ...
        'Cn_beta is missing and could not be estimated. Reason: %s', ...
        info_Cn_beta.reason);
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
out.assumptions.input_source = 'AVS_input_lateral_current.m';
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
out.inertia.Ixz = Ixz;                 % input value, stored for reference
out.inertia.Ixz_input_is_zero = (Ixz == 0);
out.inertia.Ixz_active = 0;            % active model assumption at this stage
out.inertia.Ixz_coupling_used = false; % no starred derivatives in current core
out.inertia.Ixz_assumption_note = ...
    'Input Ixz is stored, but the active lateral state-space model uses Ixz = 0 and does not apply starred derivatives.';

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

out.derivative_sources.Cl_beta = struct();
out.derivative_sources.Cl_beta.source = src_Cl_beta;
out.derivative_sources.Cl_beta.value = Cl_beta;
out.derivative_sources.Cl_beta.info = info_Cl_beta;

out.derivative_sources.Cn_beta = struct();
out.derivative_sources.Cn_beta.source = src_Cn_beta;
out.derivative_sources.Cn_beta.value = Cn_beta;
out.derivative_sources.Cn_beta.info = info_Cn_beta;

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

out.nelson_estimates.Cl_beta = struct();
out.nelson_estimates.Cl_beta.value = Cl_beta_Nelson;
out.nelson_estimates.Cl_beta.source = 'calculated_Nelson_Fig_3_11_not_input';
out.nelson_estimates.Cl_beta.info = info_Cl_beta_Nelson;

out.nelson_estimates.Cl_beta_over_Gamma = struct();
out.nelson_estimates.Cl_beta_over_Gamma.value_per_deg2 = info_Cl_beta_Nelson.Clbeta_over_Gamma_per_deg2;
out.nelson_estimates.Cl_beta_over_Gamma.source = 'calculated_Nelson_Fig_3_11_not_input';
out.nelson_estimates.Cl_beta_over_Gamma.info = info_Cl_beta_Nelson;

out.nelson_estimates.Cn_beta = struct();
out.nelson_estimates.Cn_beta.value = Cn_beta_Nelson;
out.nelson_estimates.Cn_beta.source = 'calculated_Nelson_Eq_2_73_Fig_2_29_Fig_2_30_plus_vertical_tail_not_input';
out.nelson_estimates.Cn_beta.info = info_Cn_beta_Nelson;

out.nelson_estimates.Cn_beta_wf = struct();
out.nelson_estimates.Cn_beta_wf.value_per_rad = info_Cn_beta_Nelson.Cn_beta_wf_per_rad;
out.nelson_estimates.Cn_beta_wf.value_per_deg = info_Cn_beta_Nelson.Cn_beta_wf_per_deg;
out.nelson_estimates.Cn_beta_wf.source = 'calculated_Nelson_Eq_2_73_Fig_2_29_Fig_2_30_not_input';
out.nelson_estimates.Cn_beta_wf.info = info_Cn_beta_Nelson.wing_fuselage;

out.nelson_estimates.Cn_beta_v = struct();
out.nelson_estimates.Cn_beta_v.value = info_Cn_beta_Nelson.Cn_beta_v;
out.nelson_estimates.Cn_beta_v.source = 'calculated_Nelson_vertical_tail_Eq_2_79_Eq_2_80_not_input';
out.nelson_estimates.Cn_beta_v.info = info_Cn_beta_Nelson;

out.nelson_estimates.kN = struct();
out.nelson_estimates.kN.value = info_Cn_beta_Nelson.kN;
out.nelson_estimates.kN.source = info_Cn_beta_Nelson.kN_source;
out.nelson_estimates.kN.info = info_Cn_beta_Nelson.wing_fuselage.kN_interpolation;

out.nelson_estimates.kRl = struct();
out.nelson_estimates.kRl.value = info_Cn_beta_Nelson.kRl;
out.nelson_estimates.kRl.source = info_Cn_beta_Nelson.kRl_source;
out.nelson_estimates.kRl.info = info_Cn_beta_Nelson.wing_fuselage.kRl_interpolation;

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
out.normalized.Y_delta_r_over_m_raw = Y_delta_r_over_m;
out.normalized.Y_delta_r_over_m = Y_delta_r_over_m / u0_fps;
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

spiral_expr_dimensional = L_beta*N_r - L_r*N_beta;
spiral_expr_normalized = num_spiral_approx;

if isfinite(spiral_expr_normalized)
    if spiral_expr_normalized > 0
        spiral_result_text = 'STABLE';
    elseif spiral_expr_normalized < 0
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
out.static_stability.spiral.condition = 'normalized L_beta*N_r - L_r*N_beta > 0';
out.static_stability.spiral.expression_value = spiral_expr_normalized;
out.static_stability.spiral.expression_value_dimensional = spiral_expr_dimensional;
out.static_stability.spiral.lambda_approx = lambda_spiral_approx;
out.static_stability.spiral.lambda_exact = spiral_mode_exact;
out.static_stability.spiral.L_beta = L_beta;
out.static_stability.spiral.N_r = N_r;
out.static_stability.spiral.L_r = L_r;
out.static_stability.spiral.N_beta = N_beta;
out.static_stability.spiral.sign_pattern_ok = spiral_sign_pattern_ok;
out.static_stability.spiral.result_text = spiral_result_text;
out.static_stability.spiral.note = spiral_note_text;

out.modal_report = struct();

out.modal_report.exact = struct();
out.modal_report.exact.roll = local_summarize_real_mode(roll_mode_exact);
out.modal_report.exact.spiral = local_summarize_real_mode(spiral_mode_exact);
out.modal_report.exact.dutch = local_summarize_complex_mode(dutch_mode_exact);

out.modal_report.approx = struct();
out.modal_report.approx.roll = local_summarize_real_mode(lambda_roll_approx);
out.modal_report.approx.spiral = local_summarize_real_mode(lambda_spiral_approx);
out.modal_report.approx.dutch = local_summarize_complex_mode(eig_dutch_approx);

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

if isfinite(spiral_expr_normalized)
    if spiral_expr_normalized > 0
        fprintf('  Normalized expression = % .6f  -->  STABLE\n', spiral_expr_normalized);
    elseif spiral_expr_normalized < 0
        fprintf('  Normalized expression = % .6f  -->  UNSTABLE\n', spiral_expr_normalized);
    else
        fprintf('  Normalized expression = % .6f  -->  NEUTRAL / MARGINAL\n', spiral_expr_normalized);
    end
    fprintf('  Raw dimensional expression = % .6e\n', spiral_expr_dimensional);
    fprintf('  Approx spiral eigenvalue = % .6e 1/s\n', lambda_spiral_approx);
    fprintf('  Exact spiral eigenvalue  = % .6e 1/s\n', real(spiral_mode_exact));
else
    fprintf('  Normalized expression = NaN  -->  UNDETERMINED\n');
end

if spiral_sign_pattern_ok
    fprintf('  Note: Required sign pattern satisfied: L_beta<0, N_r<0, L_r>0, N_beta>0\n');
else
    fprintf('  Note: Required sign pattern NOT satisfied, so THIS RESULT SHOULD BE TREATED WITH CAUTION\n');
end

fprintf('\n---- Lateral/Directional Mode Classification ----\n');

fprintf('\nExact dynamic modes \n');
local_print_real_mode_summary('Roll mode', out.modal_report.exact.roll);
local_print_real_mode_summary('Spiral mode', out.modal_report.exact.spiral);
local_print_complex_mode_summary('Dutch roll', out.modal_report.exact.dutch);

fprintf('\nApproximate modal side notes \n');
local_print_real_mode_summary('Roll approximation', out.modal_report.approx.roll);
local_print_real_mode_summary('Spiral approximation', out.modal_report.approx.spiral);
local_print_complex_mode_summary('Dutch-roll approximation', out.modal_report.approx.dutch);

end

function s = local_summarize_real_mode(lambda_value)
%LOCAL_SUMMARIZE_REAL_MODE
% Summarize a real lateral/directional mode.

    tol = 1.0e-10;

    s = struct();
    s.lambda = lambda_value;
    s.status = 'UNDETERMINED';
    s.description = 'Unavailable / not a finite real mode';
    s.tau = NaN;
    s.time_to_half = NaN;
    s.time_to_double = NaN;

    if ~isnumeric(lambda_value) || ~isscalar(lambda_value)
        return;
    end

    if ~isfinite(real(lambda_value)) || ~isfinite(imag(lambda_value))
        return;
    end

    if abs(imag(lambda_value)) > 1.0e-8
        s.description = 'Not reported here because this is not a real mode';
        return;
    end

    lambda_real = real(lambda_value);
    s.lambda = lambda_real;

    if lambda_real < -tol
        s.status = 'STABLE';
        s.description = 'Stable Decaying Exponential';
        s.tau = -1 / lambda_real;
        s.time_to_half = log(2) / (-lambda_real);
    elseif lambda_real > tol
        s.status = 'UNSTABLE';
        s.description = 'Unstable Growing Exponential';
        s.time_to_double = log(2) / lambda_real;
    else
        s.status = 'NEUTRAL / MARGINAL';
        s.description = 'Neutral / Marginal Real Mode';
    end
end

function s = local_summarize_complex_mode(lambda_pair)
%LOCAL_SUMMARIZE_COMPLEX_MODE
% Summarize an oscillatory lateral/directional mode pair.

    tol = 1.0e-10;

    s = struct();
    s.eigenvalues = lambda_pair;
    s.reference_eigenvalue = NaN;
    s.status = 'UNDETERMINED';
    s.description = 'Unavailable / no finite complex pair detected';
    s.sigma = NaN;
    s.omega_d = NaN;
    s.omega_n = NaN;
    s.zeta = NaN;
    s.period = NaN;
    s.tau = NaN;
    s.time_to_double = NaN;

    if ~isnumeric(lambda_pair)
        return;
    end

    lambda_values = lambda_pair(:);
    finite_mask = isfinite(real(lambda_values)) & isfinite(imag(lambda_values));
    lambda_values = lambda_values(finite_mask);

    complex_mask = abs(imag(lambda_values)) > 1.0e-8;
    complex_values = lambda_values(complex_mask);

    if isempty(complex_values)
        return;
    end

    [~, idx] = max(abs(imag(complex_values)));
    lambda_ref = complex_values(idx);

    sigma = real(lambda_ref);
    omega_d = abs(imag(lambda_ref));
    omega_n = sqrt(sigma^2 + omega_d^2);

    s.reference_eigenvalue = lambda_ref;
    s.sigma = sigma;
    s.omega_d = omega_d;
    s.omega_n = omega_n;

    if omega_n > 0
        s.zeta = -sigma / omega_n;
    end

    if omega_d > 0
        s.period = 2*pi / omega_d;
    end

    if sigma < -tol
        s.status = 'STABLE';
        s.description = 'Stable Decaying Oscillation';
        s.tau = -1 / sigma;
    elseif sigma > tol
        s.status = 'UNSTABLE';
        s.description = 'Unstable Growing Oscillation';
        s.time_to_double = log(2) / sigma;
    else
        s.status = 'NEUTRAL / MARGINAL';
        s.description = 'Neutral / Undamped Oscillation';
    end
end

function local_print_real_mode_summary(label_text, s)
%LOCAL_PRINT_REAL_MODE_SUMMARY
% Print a real-mode summary in the lateral/directional report.

    if ~isfield(s, 'lambda') || ~isfinite(real(s.lambda)) || ~isfinite(imag(s.lambda))
        fprintf('  %-24s : unavailable\n', label_text);
        return;
    end

    if abs(imag(s.lambda)) > 1.0e-8
        fprintf('  %-24s : not a real mode\n', label_text);
        return;
    end

    fprintf('  %-24s : lambda = % .6e 1/s\n', label_text, real(s.lambda));
    fprintf('                           %s --> %s\n', s.description, s.status);

    if isfield(s, 'tau') && isfinite(s.tau)
        fprintf('                           tau = %.3f s, time-to-half = %.3f s\n', ...
            s.tau, s.time_to_half);
    elseif isfield(s, 'time_to_double') && isfinite(s.time_to_double)
        fprintf('                           time-to-double = %.3f s\n', s.time_to_double);
    end
end

function local_print_complex_mode_summary(label_text, s)
%LOCAL_PRINT_COMPLEX_MODE_SUMMARY
% Print an oscillatory-mode summary in the lateral/directional report.

    if ~isfield(s, 'reference_eigenvalue') || ...
            ~isfinite(real(s.reference_eigenvalue)) || ...
            ~isfinite(imag(s.reference_eigenvalue))
        fprintf('  %-24s : unavailable / no complex pair detected\n', label_text);
        return;
    end

    fprintf('  %-24s : lambda = % .6e +/- %.6ei 1/s\n', ...
        label_text, s.sigma, s.omega_d);
    fprintf('                           %s --> %s\n', s.description, s.status);
    fprintf('                           zeta = %.3f, omega_n = %.6f rad/s, omega_d = %.6f rad/s\n', ...
        s.zeta, s.omega_n, s.omega_d);

    if isfield(s, 'period') && isfinite(s.period)
        fprintf('                           period = %.3f s\n', s.period);
    end

    if isfield(s, 'tau') && isfinite(s.tau)
        fprintf('                           decay time constant tau = %.3f s\n', s.tau);
    elseif isfield(s, 'time_to_double') && isfinite(s.time_to_double)
        fprintf('                           time-to-double = %.3f s\n', s.time_to_double);
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
%   sectional ratio, as in the current validation example.
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

function [Cl_beta_est, info] = avs_estimate_Cl_beta_Nelson(pAV)
%AVS_ESTIMATE_CL_BETA_NELSON
% Estimate rolling-moment derivative due to sideslip, Cl_beta, using
% digitized Nelson Fig. 3.11.
%
% Fig. 3.11 provides (Cl_beta / Gamma) as a function of aspect ratio and
% taper ratio. The digitized CSV stores this ratio in units of 1/deg^2.
%
% Therefore:
%   Cl_beta_per_deg = (Cl_beta/Gamma)_fig * Gamma_deg
%   Cl_beta_per_rad = Cl_beta_per_deg * (180/pi)

    info = struct();
    info.method = 'Nelson Fig. 3.11 with digitized CSV';
    info.used_estimate = true;
    info.reason = '';

    AR = avs_get_numeric_field(pAV, 'AR');
    if ~isfinite(AR)
        b_tmp = avs_get_numeric_field(pAV, 'b');
        S_tmp = avs_get_numeric_field(pAV, 'S');
        if isfinite(b_tmp) && isfinite(S_tmp) && S_tmp > 0
            AR = b_tmp^2 / S_tmp;
        end
    end

    taperRatio = avs_get_numeric_field(pAV, 'TaperRatio');
    Gamma_deg = avs_get_numeric_field(pAV, 'Gamma_w');

    ratio_direct = avs_get_numeric_field(pAV, 'Clbeta_over_Gamma_fig_3_11');

    if isfinite(ratio_direct)
        Clbeta_over_Gamma_per_deg2 = ratio_direct;
        info.ratio_source = 'pAV.Clbeta_over_Gamma_fig_3_11';
        csvPath = '';
    else
        csvPath = avs_resolve_fig_3_11_csv_path(pAV);
        [Clbeta_over_Gamma_per_deg2, infoInterp] = ...
            avs_interp_Clbeta_over_Gamma_fig_3_11(csvPath, AR, taperRatio);

        info.ratio_source = 'digitized Nelson Fig. 3.11 CSV';
        info.interpolation = infoInterp;
    end

    required = [AR, taperRatio, Gamma_deg, Clbeta_over_Gamma_per_deg2];

    if any(~isfinite(required))
        Cl_beta_est = NaN;
        info.reason = ['Missing one or more fields needed for Cl_beta estimate: ', ...
                       'AR or b and S, TaperRatio, Gamma_w, and Fig. 3.11 data.'];
        info.AR = AR;
        info.taperRatio = taperRatio;
        info.Gamma_deg = Gamma_deg;
        info.Clbeta_over_Gamma_per_deg2 = Clbeta_over_Gamma_per_deg2;
        info.csvPath = csvPath;
        return;
    end

    Cl_beta_per_deg = Clbeta_over_Gamma_per_deg2 * Gamma_deg;
    Cl_beta_est = Cl_beta_per_deg * (180/pi);

    info.reason = 'Cl_beta estimated successfully.';
    info.AR = AR;
    info.taperRatio = taperRatio;
    info.Gamma_deg = Gamma_deg;
    info.Clbeta_over_Gamma_per_deg2 = Clbeta_over_Gamma_per_deg2;
    info.Cl_beta_per_deg = Cl_beta_per_deg;
    info.Cl_beta_per_rad = Cl_beta_est;
    info.csvPath = csvPath;
end

function csvPath = avs_resolve_fig_3_11_csv_path(pAV)
%AVS_RESOLVE_FIG_3_11_CSV_PATH
% Resolve the file path for the digitized Nelson Fig. 3.11 CSV.

    defaultName = 'figure_3_11_digitized_second_pass.csv';
    csvPath = defaultName;

    if isfield(pAV, 'fig_3_11_csv') && ~isempty(pAV.fig_3_11_csv)
        if ischar(pAV.fig_3_11_csv)
            csvPath = pAV.fig_3_11_csv;
        elseif isstring(pAV.fig_3_11_csv)
            csvPath = char(pAV.fig_3_11_csv);
        end
    end

    if isfile(csvPath)
        return;
    end

    if isfield(pAV, 'digitized_figures_folder') && ~isempty(pAV.digitized_figures_folder)
        figFolder = char(pAV.digitized_figures_folder);
        candidatePath = fullfile(figFolder, defaultName);
        if isfile(candidatePath)
            csvPath = candidatePath;
            return;
        end
    end

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

function [Clbeta_over_Gamma_per_deg2, info] = ...
    avs_interp_Clbeta_over_Gamma_fig_3_11(csvPath, AR, taperRatio)
%AVS_INTERP_CLBETA_OVER_GAMMA_FIG_3_11
% Interpolate (Cl_beta / Gamma) from digitized Nelson Fig. 3.11 CSV.
%
% Expected CSV format:
%   aspect_ratio,
%   clbeta_over_gamma_lambda_0_per_deg2,
%   clbeta_over_gamma_lambda_0_5_per_deg2,
%   clbeta_over_gamma_lambda_1_per_deg2

    info = struct();
    info.reason = '';
    info.csvPath = csvPath;
    info.AR = AR;
    info.taperRatio = taperRatio;

    Clbeta_over_Gamma_per_deg2 = NaN;

    if nargin < 3 || ~isfinite(AR) || ~isfinite(taperRatio)
        info.reason = 'AR and/or taperRatio are not finite.';
        return;
    end

    if ~isfile(csvPath)
        info.reason = sprintf('Fig. 3.11 CSV file was not found at: %s', csvPath);
        return;
    end

    T = readtable(csvPath);
    varNames = T.Properties.VariableNames;

    if numel(varNames) < 2
        info.reason = 'Fig. 3.11 CSV does not contain enough columns.';
        return;
    end

    AR_data = T.(varNames{1});

    lambdaData = [];
    ratioData = [];

    for j = 2:numel(varNames)
        token = regexp(varNames{j}, 'lambda_([0-9]+(?:_[0-9]+)?)_per_deg2', ...
            'tokens', 'once');

        if isempty(token)
            continue;
        end

        lambdaText = token{1};
        lambdaText = strrep(lambdaText, '_', '.');
        lambdaValue = str2double(lambdaText);

        if ~isfinite(lambdaValue)
            continue;
        end

        lambdaData(end+1) = lambdaValue; %#ok<AGROW>
        ratioData(:,end+1) = T.(varNames{j}); %#ok<AGROW>
    end

    if isempty(lambdaData)
        info.reason = 'Could not identify taper-ratio columns in Fig. 3.11 CSV.';
        return;
    end

    [lambdaData, order] = sort(lambdaData);
    ratioData = ratioData(:,order);

    ARMin = min(AR_data);
    ARMax = max(AR_data);
    lambdaMin = min(lambdaData);
    lambdaMax = max(lambdaData);

    info.AR_range = [ARMin, ARMax];
    info.lambda_range = [lambdaMin, lambdaMax];

    if AR < ARMin || AR > ARMax
        info.reason = 'AR is outside the digitized Fig. 3.11 aspect-ratio range.';
        return;
    end

    if taperRatio < lambdaMin || taperRatio > lambdaMax
        info.reason = 'TaperRatio is outside the digitized Fig. 3.11 taper-ratio range.';
        return;
    end

    ratio_vs_lambda = NaN(size(lambdaData));

    for j = 1:numel(lambdaData)
        ratio_vs_lambda(j) = interp1(AR_data, ratioData(:,j), AR, 'linear');
    end

    Clbeta_over_Gamma_per_deg2 = interp1(lambdaData, ratio_vs_lambda, taperRatio, 'linear');

    if isfinite(Clbeta_over_Gamma_per_deg2)
        info.reason = 'Cl_beta/Gamma interpolated successfully from digitized Fig. 3.11.';
        info.lambdaData = lambdaData;
        info.ratio_vs_lambda_at_AR = ratio_vs_lambda;
        info.Clbeta_over_Gamma_per_deg2 = Clbeta_over_Gamma_per_deg2;
    else
        info.reason = 'Interpolation returned NaN.';
    end
end
function [Cn_beta_est, info] = avs_estimate_Cn_beta_Nelson(pAV)
%AVS_ESTIMATE_CN_BETA_NELSON
% Estimate total directional-stability derivative Cn_beta.
%
% Components:
%   Cn_beta_wf : wing-fuselage contribution from Nelson Eq. [2.73]
%   Cn_beta_v  : vertical-tail contribution using Nelson Eq. [2.79]/[2.80]
%
% Nelson Eq. [2.73] gives Cn_beta_wf per degree, so it is converted to
% per radian before combining with the vertical-tail contribution.

    info = struct();
    info.method = 'Nelson Eq. [2.73], Fig. 2.29, Fig. 2.30, plus vertical-tail contribution';
    info.used_estimate = true;
    info.reason = '';

    info.kN = NaN;
    info.kRl = NaN;
    info.kN_source = '';
    info.kRl_source = '';
    info.Cn_beta_wf_per_deg = NaN;
    info.Cn_beta_wf_per_rad = NaN;
    info.Cn_beta_v = NaN;
    info.Cn_beta_total = NaN;
    info.wing_fuselage = struct();

    [Cn_beta_wf_per_rad, infoWF] = avs_estimate_Cn_beta_wf_Nelson(pAV);

    info.wing_fuselage = infoWF;
    info.kN = infoWF.kN;
    info.kRl = infoWF.kRl;
    info.kN_source = infoWF.kN_source;
    info.kRl_source = infoWF.kRl_source;
    info.Cn_beta_wf_per_deg = infoWF.Cn_beta_wf_per_deg;
    info.Cn_beta_wf_per_rad = Cn_beta_wf_per_rad;

    S = avs_get_numeric_field(pAV, 'S');
    b = avs_get_numeric_field(pAV, 'b');

    R_280 = avs_get_numeric_field(pAV, 'R_280');

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

    if all(isfinite([R_280, S_v, l_v, CL_alpha_v, S, b])) && S > 0 && b > 0
        info.Cn_beta_v = R_280 * CL_alpha_v * S_v * l_v / (S * b);
    else
        info.Cn_beta_v = NaN;
    end

    if all(isfinite([info.Cn_beta_wf_per_rad, info.Cn_beta_v]))
        Cn_beta_est = info.Cn_beta_wf_per_rad + info.Cn_beta_v;
        info.Cn_beta_total = Cn_beta_est;
        info.reason = 'Cn_beta estimated successfully.';
    else
        Cn_beta_est = NaN;
        info.reason = ['Could not estimate total Cn_beta. Need both Cn_beta_wf ', ...
                       'and vertical-tail Cn_beta_v. Check wing_fuselage.reason ', ...
                       'and vertical-tail support fields R_280, S_v/Sv, l_v/lv, CL_alpha_v/Cla_v.'];
    end

    info.S = S;
    info.b = b;
    info.R_280 = R_280;
    info.S_v = S_v;
    info.l_v = l_v;
    info.CL_alpha_v = CL_alpha_v;
end

function [Cn_beta_wf_per_rad, info] = avs_estimate_Cn_beta_wf_Nelson(pAV)
%AVS_ESTIMATE_CN_BETA_WF_NELSON
% Estimate wing-fuselage contribution to Cn_beta using Nelson Eq. [2.73].
%
% Nelson Eq. [2.73]:
%   Cn_beta_wf = -k_N*k_Rl*S_fs*l_f/(S*b)     per degree
%
% The code converts the result to per radian:
%   Cn_beta_wf_per_rad = Cn_beta_wf_per_deg * 180/pi

    info = struct();
    info.method = 'Nelson Eq. [2.73] using Fig. 2.29 k_N and Fig. 2.30 k_Rl';
    info.used_estimate = true;
    info.reason = '';

    info.kN = NaN;
    info.kRl = NaN;
    info.kN_source = '';
    info.kRl_source = '';
    info.Cn_beta_wf_per_deg = NaN;
    info.Cn_beta_wf_per_rad = NaN;
    info.kN_interpolation = struct();
    info.kRl_interpolation = struct();

    S = avs_get_numeric_field(pAV, 'S');
    b = avs_get_numeric_field(pAV, 'b');

    S_fs = avs_get_numeric_field(pAV, 'S_fs');
    if ~isfinite(S_fs)
        S_fs = avs_get_numeric_field(pAV, 'S_bs');
    end

    l_f = avs_get_numeric_field(pAV, 'l_f');

        % Always calculate the Nelson Fig. 2.29 and Fig. 2.30 factors for
    % reporting/comparison. Do not let optional pAV.kN or pAV.kRl override
    % the stored Nelson estimate.
    [kN, infoKN] = avs_estimate_kN_fig_2_29(pAV);
    info.kN_source = 'digitized Nelson Fig. 2.29 CSV';
    info.kN_interpolation = infoKN;

    [kRl, infoKRl] = avs_estimate_kRl_fig_2_30(pAV);
    info.kRl_source = 'digitized Nelson Fig. 2.30 CSV';
    info.kRl_interpolation = infoKRl;
    required = [S, b, S_fs, l_f, kN, kRl];

    if any(~isfinite(required))
        Cn_beta_wf_per_rad = NaN;
        info.reason = ['Missing one or more fields needed for Cn_beta_wf: ', ...
                       'S, b, S_fs/S_bs, l_f, kN/Fig.2.29 inputs, and kRl/Fig.2.30 inputs.'];
        info.S = S;
        info.b = b;
        info.S_fs = S_fs;
        info.l_f = l_f;
        info.kN = kN;
        info.kRl = kRl;
        return;
    end

    if S <= 0 || b <= 0 || S_fs <= 0 || l_f <= 0 || kN <= 0 || kRl <= 0
        Cn_beta_wf_per_rad = NaN;
        info.reason = 'Invalid geometry or correction factors for Cn_beta_wf.';
        info.S = S;
        info.b = b;
        info.S_fs = S_fs;
        info.l_f = l_f;
        info.kN = kN;
        info.kRl = kRl;
        return;
    end

    Cn_beta_wf_per_deg = -kN * kRl * S_fs * l_f / (S * b);
    Cn_beta_wf_per_rad = Cn_beta_wf_per_deg * (180/pi);

    info.reason = 'Cn_beta_wf estimated successfully.';
    info.S = S;
    info.b = b;
    info.S_fs = S_fs;
    info.l_f = l_f;
    info.kN = kN;
    info.kRl = kRl;
    info.Cn_beta_wf_per_deg = Cn_beta_wf_per_deg;
    info.Cn_beta_wf_per_rad = Cn_beta_wf_per_rad;
end

function [kN, info] = avs_estimate_kN_fig_2_29(pAV)
%AVS_ESTIMATE_KN_FIG_2_29
% Estimate k_N using the digitized Nelson Fig. 2.29 nomogram.
%
% Required geometry:
%   S_fs, l_f, x_m, h, h1, h2, w_f
%
% Digitization-sensitive:
%   S_fs, h, h1, h2
%
% More solid:
%   w_f
%
% Reasonably solid but reference-dependent:
%   x_m

        info = struct();
    info.method = 'Digitized Nelson Fig. 2.29 nomogram';
    info.status = 'not_attempted';
    info.reason = '';
    info.interpolation_type = '';
    info.interpolation = struct();

    kN = NaN;

    S_fs = avs_get_numeric_field(pAV, 'S_fs');
    if ~isfinite(S_fs)
        S_fs = avs_get_numeric_field(pAV, 'S_bs');
    end

    l_f = avs_get_numeric_field(pAV, 'l_f');
    x_m = avs_get_numeric_field(pAV, 'x_m');
    h = avs_get_numeric_field(pAV, 'h');
    h1 = avs_get_numeric_field(pAV, 'h1');
    h2 = avs_get_numeric_field(pAV, 'h2');
    w_f = avs_get_numeric_field(pAV, 'w_f');

    required = [S_fs, l_f, x_m, h, h1, h2, w_f];

    if any(~isfinite(required))
        info.reason = 'Missing one or more Fig. 2.29 inputs: S_fs/S_bs, l_f, x_m, h, h1, h2, w_f.';
        info.S_fs = S_fs;
        info.l_f = l_f;
        info.x_m = x_m;
        info.h = h;
        info.h1 = h1;
        info.h2 = h2;
        info.w_f = w_f;
        return;
    end

    if S_fs <= 0 || l_f <= 0 || x_m <= 0 || h <= 0 || h1 <= 0 || h2 <= 0 || w_f <= 0
        info.reason = 'Invalid nonpositive Fig. 2.29 geometry input.';
        info.S_fs = S_fs;
        info.l_f = l_f;
        info.x_m = x_m;
        info.h = h;
        info.h1 = h1;
        info.h2 = h2;
        info.w_f = w_f;
        return;
    end

    x_m_over_lf = x_m / l_f;
    lf2_over_Sfs = l_f^2 / S_fs;
    sqrt_h1_h2 = sqrt(h1 / h2);
    h_over_wf = h / w_f;

    csvPath = avs_resolve_fig_2_29_csv_path(pAV);
        [kN, interpInfo] = avs_interp_kN_fig_2_29(csvPath, ...
        lf2_over_Sfs, x_m_over_lf, sqrt_h1_h2, h_over_wf);

        info.reason = interpInfo.reason;
    info.status = interpInfo.status;
    info.interpolation_type = interpInfo.interpolation_type;
    info.csvPath = csvPath;
    info.S_fs = S_fs;
    info.l_f = l_f;
    info.x_m = x_m;
    info.h = h;
    info.h1 = h1;
    info.h2 = h2;
    info.w_f = w_f;
    info.x_m_over_lf = x_m_over_lf;
    info.lf2_over_Sfs = lf2_over_Sfs;
    info.sqrt_h1_h2 = sqrt_h1_h2;
    info.h_over_wf = h_over_wf;
    info.interpolation = interpInfo;
    info.kN = kN;
end

function [kRl, info] = avs_estimate_kRl_fig_2_30(pAV)
%AVS_ESTIMATE_KRL_FIG_2_30
% Estimate k_Rl from digitized Nelson Fig. 2.30.
%
% Fig. 2.30 uses fuselage Reynolds number:
%   R_lf = V*l_f/nu

    info = struct();
    info.method = 'Digitized Nelson Fig. 2.30';
    info.reason = '';

    kRl = NaN;

    l_f = avs_get_numeric_field(pAV, 'l_f');
    nu = avs_get_numeric_field(pAV, 'nu');
    u0 = avs_get_numeric_field(pAV, 'u0');

    KT2FTPS = 1.68780985710119;

    if isfinite(u0)
        V_fps = u0 * KT2FTPS;
    else
        V_fps = NaN;
    end

    if any(~isfinite([l_f, nu, V_fps]))
        info.reason = 'Missing one or more Fig. 2.30 inputs: l_f, nu, u0.';
        info.l_f = l_f;
        info.nu = nu;
        info.V_fps = V_fps;
        info.R_lf = NaN;
        return;
    end

    if l_f <= 0 || nu <= 0 || V_fps <= 0
        info.reason = 'Invalid nonpositive Fig. 2.30 input.';
        info.l_f = l_f;
        info.nu = nu;
        info.V_fps = V_fps;
        info.R_lf = NaN;
        return;
    end

    R_lf = V_fps * l_f / nu;

    csvPath = avs_resolve_fig_2_30_csv_path(pAV);
    [kRl, interpInfo] = avs_interp_kRl_fig_2_30(csvPath, R_lf);

    info.reason = interpInfo.reason;
    info.csvPath = csvPath;
    info.l_f = l_f;
    info.nu = nu;
    info.V_fps = V_fps;
    info.R_lf = R_lf;
    info.interpolation = interpInfo;
    info.kRl = kRl;
end

function csvPath = avs_resolve_fig_2_29_csv_path(pAV)
%AVS_RESOLVE_FIG_2_29_CSV_PATH
% Resolve the file path for the digitized Nelson Fig. 2.29 CSV.

    defaultName = 'wing_body_interference_kn_digitized_v3_final.csv';
    csvPath = defaultName;

    if isfield(pAV, 'fig_2_29_csv') && ~isempty(pAV.fig_2_29_csv)
        if ischar(pAV.fig_2_29_csv)
            csvPath = pAV.fig_2_29_csv;
        elseif isstring(pAV.fig_2_29_csv)
            csvPath = char(pAV.fig_2_29_csv);
        end
    end

    if isfile(csvPath)
        return;
    end

    if isfield(pAV, 'digitized_figures_folder') && ~isempty(pAV.digitized_figures_folder)
        candidatePath = fullfile(char(pAV.digitized_figures_folder), defaultName);
        if isfile(candidatePath)
            csvPath = candidatePath;
            return;
        end
    end

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
end

function csvPath = avs_resolve_fig_2_30_csv_path(pAV)
%AVS_RESOLVE_FIG_2_30_CSV_PATH
% Resolve the file path for the digitized Nelson Fig. 2.30 CSV.

    defaultName = 'figure_2_30_digitized_samples.csv';
    csvPath = defaultName;

    if isfield(pAV, 'fig_2_30_csv') && ~isempty(pAV.fig_2_30_csv)
        if ischar(pAV.fig_2_30_csv)
            csvPath = pAV.fig_2_30_csv;
        elseif isstring(pAV.fig_2_30_csv)
            csvPath = char(pAV.fig_2_30_csv);
        end
    end

    if isfile(csvPath)
        return;
    end

    if isfield(pAV, 'digitized_figures_folder') && ~isempty(pAV.digitized_figures_folder)
        candidatePath = fullfile(char(pAV.digitized_figures_folder), defaultName);
        if isfile(candidatePath)
            csvPath = candidatePath;
            return;
        end
    end

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
end

function [kN, info] = avs_interp_kN_fig_2_29(csvPath, lf2_over_Sfs, x_m_over_lf, sqrt_h1_over_h2, h_over_wf)
%AVS_INTERP_KN_FIG_2_29
% Interpolate k_N directly from the digitized Nelson Fig. 2.29 CSV.
%
% Expected CSV columns:
%   lf2_over_Sfs, xm_over_lf, sqrt_h1_over_h2, h_over_wf,
%   construction_y, construction_p, kn, outside_digitized_chart

    info = struct();
    info.reason = '';
    info.status = 'not_attempted';
    info.csvPath = csvPath;
    info.method = 'griddedInterpolant preferred; scatteredInterpolant fallback';
    info.interpolation_type = '';

    info.lf2_over_Sfs = lf2_over_Sfs;
    info.x_m_over_lf = x_m_over_lf;
    info.sqrt_h1_over_h2 = sqrt_h1_over_h2;
    info.h_over_wf = h_over_wf;
    info.queryPoint = [lf2_over_Sfs, x_m_over_lf, sqrt_h1_over_h2, h_over_wf];

    kN = NaN;

    if ~isfile(csvPath)
        info.reason = sprintf('Fig. 2.29 CSV file was not found at: %s', csvPath);
        info.status = 'missing_csv';
        return;
    end

    if any(~isfinite([lf2_over_Sfs, x_m_over_lf, sqrt_h1_over_h2, h_over_wf]))
        info.reason = 'One or more Fig. 2.29 nondimensional inputs are not finite.';
        info.status = 'bad_inputs';
        return;
    end

    T = readtable(csvPath, 'VariableNamingRule', 'preserve', 'Delimiter', ',');
    varNames = string(T.Properties.VariableNames);
    requiredNames = ["lf2_over_Sfs", "xm_over_lf", "sqrt_h1_over_h2", "h_over_wf", "kn"];

    if any(~ismember(requiredNames, varNames))
        info.reason = 'Fig. 2.29 CSV is missing one or more required columns.';
        info.status = 'bad_csv_columns';
        info.csv_columns = cellstr(varNames);
        info.required_columns = cellstr(requiredNames);
        return;
    end

    lf2Data = T{:, 'lf2_over_Sfs'};
    xmData = T{:, 'xm_over_lf'};
    sqrtData = T{:, 'sqrt_h1_over_h2'};
    hwfData = T{:, 'h_over_wf'};
    kData = T{:, 'kn'};

    valid = isfinite(lf2Data) & isfinite(xmData) & isfinite(sqrtData) & ...
            isfinite(hwfData) & isfinite(kData);

    if ismember("outside_digitized_chart", varNames)
        outsideRaw = T{:, 'outside_digitized_chart'};

        if islogical(outsideRaw)
            outsideChart = outsideRaw;
        elseif isnumeric(outsideRaw)
            outsideChart = outsideRaw ~= 0;
        else
            outsideText = lower(strtrim(string(outsideRaw)));
            outsideChart = outsideText == "true" | outsideText == "1" | outsideText == "yes";
        end

        valid = valid & ~outsideChart;
        info.used_outside_digitized_chart_filter = true;
    else
        info.used_outside_digitized_chart_filter = false;
    end

    lf2Data = lf2Data(valid);
    xmData = xmData(valid);
    sqrtData = sqrtData(valid);
    hwfData = hwfData(valid);
    kData = kData(valid);

    info.valid_row_count = numel(kData);

    if numel(kData) < 5
        info.reason = 'Fig. 2.29 CSV has too few valid rows after filtering finite k_N and outside-chart samples.';
        info.status = 'insufficient_valid_rows';
        return;
    end

    info.lf2_over_Sfs_range = [min(lf2Data), max(lf2Data)];
    info.x_m_over_lf_range = [min(xmData), max(xmData)];
    info.sqrt_h1_over_h2_range = [min(sqrtData), max(sqrtData)];
    info.h_over_wf_range = [min(hwfData), max(hwfData)];
    info.kN_range = [min(kData), max(kData)];

    if lf2_over_Sfs < info.lf2_over_Sfs_range(1) || lf2_over_Sfs > info.lf2_over_Sfs_range(2) || ...
       x_m_over_lf < info.x_m_over_lf_range(1) || x_m_over_lf > info.x_m_over_lf_range(2) || ...
       sqrt_h1_over_h2 < info.sqrt_h1_over_h2_range(1) || sqrt_h1_over_h2 > info.sqrt_h1_over_h2_range(2) || ...
       h_over_wf < info.h_over_wf_range(1) || h_over_wf > info.h_over_wf_range(2)

        info.reason = 'Fig. 2.29 query point is outside the valid digitized data bounding box.';
        info.status = 'outside_digitized_data_range';
        return;
    end

    % Preferred path: the new Fig. 2.29 CSV is a structured grid, so use
    % griddedInterpolant. This avoids scatteredInterpolant returning NaN for
    % points that are inside the local interpolation cell but awkward in the
    % 4-D triangulation.
    try
        lf2Grid = unique(lf2Data(:));
        xmGrid = unique(xmData(:));
        sqrtGrid = unique(sqrtData(:));
        hwfGrid = unique(hwfData(:));

        lf2Grid = sort(lf2Grid);
        xmGrid = sort(xmGrid);
        sqrtGrid = sort(sqrtGrid);
        hwfGrid = sort(hwfGrid);

        K = NaN(numel(lf2Grid), numel(xmGrid), numel(sqrtGrid), numel(hwfGrid));

        for ii = 1:numel(kData)
            i1 = find(lf2Grid == lf2Data(ii), 1);
            i2 = find(xmGrid == xmData(ii), 1);
            i3 = find(sqrtGrid == sqrtData(ii), 1);
            i4 = find(hwfGrid == hwfData(ii), 1);

            if ~isempty(i1) && ~isempty(i2) && ~isempty(i3) && ~isempty(i4)
                K(i1, i2, i3, i4) = kData(ii);
            end
        end

        G = griddedInterpolant({lf2Grid, xmGrid, sqrtGrid, hwfGrid}, K, 'linear', 'none');
        kN = G(lf2_over_Sfs, x_m_over_lf, sqrt_h1_over_h2, h_over_wf);

        info.interpolation_type = 'griddedInterpolant_linear_none';
        info.grid_size = size(K);
        info.grid_nan_count = sum(isnan(K(:)));
    catch ME
        info.griddedInterpolant_error = ME.message;
        kN = NaN;
    end

    % Fallback path: keep the scattered method available, but do not rely on
    % it as the primary method for this structured Fig. 2.29 CSV.
    if ~isfinite(kN)
        try
            F = scatteredInterpolant(lf2Data, xmData, sqrtData, hwfData, kData, 'linear', 'none');
            kN = F(lf2_over_Sfs, x_m_over_lf, sqrt_h1_over_h2, h_over_wf);
            info.interpolation_type = 'scatteredInterpolant_linear_none_fallback';
        catch ME
            info.scatteredInterpolant_error = ME.message;
            info.reason = ['Fig. 2.29 gridded and scattered interpolation both failed: ', ME.message];
            info.status = 'interpolation_failed';
            return;
        end
    end

    info.kN = kN;

    if ~isfinite(kN)
        info.reason = ['Fig. 2.29 interpolation returned NaN. The query point may be outside ', ...
                       'the local valid grid cell or outside the scattered-interpolant convex hull.'];
        info.status = 'nan_interpolation_result';
        return;
    end

    if kN <= 0
        info.reason = 'Fig. 2.29 interpolation returned a nonpositive k_N, so the value was rejected.';
        info.status = 'nonpositive_kN_rejected';
        kN = NaN;
        info.kN = kN;
        return;
    end

    info.reason = 'k_N interpolated successfully from valid digitized Fig. 2.29 samples.';
    info.status = 'ok';
end

function [kRl, info] = avs_interp_kRl_fig_2_30(csvPath, R_lf)
%AVS_INTERP_KRL_FIG_2_30
% Interpolate k_Rl from digitized Nelson Fig. 2.30 using log10(R_lf).
%
% Expected CSV columns:
%   k_Rl, Rlf_x1e_minus6, Rlf

    info = struct();
    info.reason = '';
    info.status = 'not_attempted';
    info.csvPath = csvPath;
    info.R_lf = R_lf;
    info.method = 'interp1 linear in log10(R_lf) from digitized Fig. 2.30 samples';

    kRl = NaN;

    if ~isfile(csvPath)
        info.reason = sprintf('Fig. 2.30 CSV file was not found at: %s', csvPath);
        info.status = 'missing_csv';
        return;
    end

    if ~isfinite(R_lf) || R_lf <= 0
        info.reason = 'R_lf is not finite or not positive.';
        info.status = 'bad_input';
        return;
    end

    T = readtable(csvPath, 'VariableNamingRule', 'preserve', 'Delimiter', ',');
    varNames = string(T.Properties.VariableNames);

    if ismember("k_Rl", varNames)
        kData = T{:, 'k_Rl'};
    elseif width(T) >= 1
        kData = T{:, 1};
    else
        info.reason = 'Fig. 2.30 CSV does not contain a k_Rl column.';
        info.status = 'bad_csv_columns';
        return;
    end

    if ismember("Rlf", varNames)
        RData = T{:, 'Rlf'};
    elseif width(T) >= 3
        RData = T{:, 3};
    else
        info.reason = 'Fig. 2.30 CSV does not contain an Rlf column or at least 3 columns.';
        info.status = 'bad_csv_columns';
        return;
    end

    valid = isfinite(kData) & isfinite(RData) & RData > 0 & kData > 0;
    kData = kData(valid);
    RData = RData(valid);

    info.valid_row_count = numel(kData);

    if numel(kData) < 2
        info.reason = 'Fig. 2.30 CSV has too few valid rows after filtering.';
        info.status = 'insufficient_valid_rows';
        return;
    end

    [RData, order] = sort(RData);
    kData = kData(order);

    [RData, uniqueIdx] = unique(RData, 'stable');
    kData = kData(uniqueIdx);

    info.R_lf_range = [min(RData), max(RData)];
    info.log10_R_lf_range = log10(info.R_lf_range);
    info.kRl_range = [min(kData), max(kData)];
    info.query_log10_R_lf = log10(R_lf);

    if R_lf < info.R_lf_range(1) || R_lf > info.R_lf_range(2)
        info.reason = 'R_lf is outside the digitized Fig. 2.30 range.';
        info.status = 'outside_digitized_data_range';
        return;
    end

    kRl = interp1(log10(RData), kData, log10(R_lf), 'linear');
    info.kRl = kRl;

    if ~isfinite(kRl)
        info.reason = 'Fig. 2.30 interpolation returned NaN.';
        info.status = 'nan_interpolation_result';
        return;
    end

    if kRl <= 0
        info.reason = 'Fig. 2.30 interpolation returned a nonpositive k_Rl, so the value was rejected.';
        info.status = 'nonpositive_kRl_rejected';
        kRl = NaN;
        info.kRl = kRl;
        return;
    end

    info.reason = 'k_Rl interpolated successfully from digitized Fig. 2.30 using log10(R_lf).';
    info.status = 'ok';
end