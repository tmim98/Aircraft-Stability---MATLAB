function out = SI_longitudinal_analysis_grouped(p)
% SI_LONGITUDINAL_ANALYSIS_GROUPED
% Compute longitudinal stability/control derivatives and grouped output structs.
% Input: p struct with SI fields. Missing optional fields are handled by defaults or NaN where appropriate.
%   Required / commonly used fields (set as appropriate for your airplane):
%     p.rho        - air density (kg/m^3)
%     p.u0         - flight speed (m/s)
%     p.S          - wing area (m^2)
%     p.St         - horizontal tail area (m^2)
%     p.c_bar      - mean aerodynamic chord (m)
%     p.lt         - distance c.g. to tail quarter-chord (m)
%     p.x_cg       - center of gravity location (m from same datum as x_ac)
%     p.x_ac       - aerodynamic center location (m)
%     p.CL0        - reference lift coefficient (operating point)
%     p.CL_alpha   - airplane lift curve slope (per rad)
%     p.CL_alpha_w - wing lift curve slope (per rad)
%     p.CL_alpha_t - tail lift curve slope (per rad)
%     p.eta        - tail dynamic pressure ratio (Q_t/Q_w) (default=1)
%     p.AR_w       - wing aspect ratio
%     p.iw         - wing incidence (rad)
%     p.it         - tail incidence (rad)
%     p.epsilon0   - downwash at zero AoA (rad)
%     p.Cm0_w      - wing moment coefficient about wing AC
%     p.Cm0_f      - fuselage zero-moment term
%     p.Cm_af      - fuselage contribution to Cm_alpha
%     p.dEdalpha   - d(epsilon)/d(alpha)  (downwash gradient)
%     p.dCLt_ddeltaE  - dC_L_tail / d(delta_e)  (per rad)
%     p.C_L_del   - dC_L / d(delta) for whole airplane (optional)
%     p.S_t_ratio  - St/S (optional)
%     p.m          - mass (kg)
%     p.Iyy        - moment of inertia about pitch (kg m^2)
%     p.g          - gravity (m/s^2) (default 9.80665)
%     p.C_D0       - zero-lift drag coeff
%     p.C_Du       - derivative drag with respect to (w.r.t) u (optional)
%     p.C_Lu       - derivative lift w.r.t u (optional)
%
%   Outputs in struct out:
%     Cm_alpha, Cm0, x_NP (stick-fixed neutral point), Cm_deltaE, delta_trim,
%     Stability derivatives X_u, X_w, Z_u, Z_w, M_u, M_w, M_q, M_alpha_dot, A, B, eigenvalues,
%     short/long period metrics (omega_n_sp, zeta_sp, omega_n_lp, zeta_lp)

% Provide defaults
if ~isfield(p,'eta'), p.eta = 1; end
if ~isfield(p,'g'), p.g = 9.80665; end
if ~isfield(p,'S_t_ratio'), p.S_t_ratio = p.St / p.S; end

% shorthand
eta = p.eta;
S = p.S;
St = p.St;
c = p.c_bar;                                                         %ΣΤΟΝ ΠΙΝΑΚΑ 3.5 ΕΧΕΙ c ΚΑΙ c_bar ---ΤΑ ΑΝΤΙΜΕΤΩΠΙΖΟΥΜΕ ΔΙΑΦΟΡΕΤΙΚΑ? %
lt = p.lt;
x_cg = p.x_cg;
x_ac = p.x_ac;
CL0 = p.CL0;
CL_alpha = p.CL_alpha;
CL_aw = p.CL_alpha_w;
CL_at = p.CL_alpha_t;
ARw = p.AR_w; %#ok<NASGU>
dEdalpha = p.dEdalpha;
V_H = (lt*St)/(S*c);  % horizontal tail volume ratio

% ---- 2.3 Static stability ----
% Cm_alpha (C_{m_alpha}) [Eq 2.3 and 2.35]
if isfield(p,'Cm_alpha')
    Cm_alpha = p.Cm_alpha;   % preferred direct input
else
    Cm_alpha = CL_aw * ( (x_cg - x_ac)/c ) + p.Cm_af - eta*V_H*CL_at*(1 - dEdalpha);
end
% ---- Static longitudinal stability (Nelson Eq. 2.2) ----
if CL_alpha ~= 0
    dCm_dCL = Cm_alpha / CL_alpha;
else
    dCm_dCL = NaN;
end

tol = 1e-6;

if ~isnan(dCm_dCL)
    if dCm_dCL < -tol
        fprintf('Static longitudinal stability: STABLE (dCm/dCL = %.6f)\n', dCm_dCL);
    elseif dCm_dCL > tol
        fprintf('Static longitudinal stability: UNSTABLE (dCm/dCL = %.6f)\n', dCm_dCL);
    else
        fprintf('Static longitudinal stability: NEUTRAL (dCm/dCL ≈ 0)\n');
    end
else
    disp('Static longitudinal stability: UNDEFINED (CL_alpha = 0)');
end


% Cm0 [Eq 2.34]
% Prefer direct Cm0 when supplied. Otherwise keep the original separated
% Nelson-style component calculation for older input files.
if isfield(p,'Cm0') && ~isempty(p.Cm0) && isfinite(p.Cm0)
    Cm0 = p.Cm0;
else
    Cm0 = p.Cm0_w + p.Cm0_f + eta*V_H*CL_at*(p.epsilon0 + p.iw - p.it);
end

% Stick-fixed neutral point x_NP/c  [Eq 2.36]
x_NP_by_c = x_ac/c - p.Cm_af/CL_aw + eta*V_H*(CL_at/CL_aw)*(1 - dEdalpha);
x_NP = x_NP_by_c * c;

% Static margin from the neutral-point calculation (dimensionless)
SM = (x_NP - x_cg) / c;

% Static margin implied by the direct Cm_alpha / CL_alpha relation.
% This is stored as a consistency check, not as a replacement for the
% neutral-point-based value above.
if isfinite(Cm_alpha) && isfinite(CL_alpha) && CL_alpha ~= 0
    SM_from_Cm_alpha = -Cm_alpha / CL_alpha;
    x_NP_from_Cm_alpha = x_cg + SM_from_Cm_alpha * c;
    x_NP_by_c_from_Cm_alpha = x_NP_from_Cm_alpha / c;
else
    SM_from_Cm_alpha = NaN;
    x_NP_from_Cm_alpha = NaN;
    x_NP_by_c_from_Cm_alpha = NaN;
end

SM_estimates = [SM, SM_from_Cm_alpha];
valid_SM_estimates = SM_estimates(isfinite(SM_estimates));

if numel(valid_SM_estimates) >= 2
    SM_estimate_range = [min(valid_SM_estimates), max(valid_SM_estimates)];

    if all(valid_SM_estimates > tol)
        static_margin_note = sprintf([ ...
            'Static-margin estimates bracket a positive range of %.4f to %.4f MAC; ', ...
            'both checks indicate positive longitudinal static stability.'], ...
            SM_estimate_range(1), SM_estimate_range(2));
    elseif all(valid_SM_estimates < -tol)
        static_margin_note = sprintf([ ...
            'Static-margin estimates bracket a negative range of %.4f to %.4f MAC; ', ...
            'both checks indicate longitudinal static instability.'], ...
            SM_estimate_range(1), SM_estimate_range(2));
    elseif any(abs(valid_SM_estimates) <= tol)
        static_margin_note = sprintf([ ...
            'At least one static-margin estimate is close to neutral. ', ...
            'Neutral-point SM = %.4f MAC, Cm_alpha-based SM = %.4f MAC.'], ...
            SM, SM_from_Cm_alpha);
    else
        static_margin_note = sprintf([ ...
            'Static-margin estimates disagree in sign. ', ...
            'Neutral-point SM = %.4f MAC, Cm_alpha-based SM = %.4f MAC. ', ...
            'Review the input assumptions before interpreting static stability.'], ...
            SM, SM_from_Cm_alpha);
    end
elseif isscalar(valid_SM_estimates)
    SM_estimate_range = [valid_SM_estimates(1), valid_SM_estimates(1)];
    static_margin_note = sprintf('Only one static-margin estimate is available: %.4f MAC.', valid_SM_estimates(1));
else
    SM_estimate_range = [NaN, NaN];
    static_margin_note = 'No finite static-margin estimate is available.';
end

fprintf('Static margin from neutral-point calculation = %.4f (positive = stable)\n', SM);
fprintf('Static margin implied by -Cm_alpha/CL_alpha = %.4f (side note)\n', SM_from_Cm_alpha);
fprintf('%s\n', static_margin_note);

out.static_margin = SM;
out.static_margin_from_neutral_point = SM;
out.static_margin_from_Cm_alpha = SM_from_Cm_alpha;
out.static_margin_estimate_range = SM_estimate_range;
out.static_margin_note = static_margin_note;
out.dCm_dCL = dCm_dCL;

% ---- Elevator effectiveness and trim ----
% C_m_deltaE (elevator control power) [Eq 2.44 and 2.45]

if isfield(p,'C_m_deltaE')
    C_m_deltaE = p.C_m_deltaE;          % preferred direct input
elseif isfield(p,'Cm_deltaE')
    C_m_deltaE = p.Cm_deltaE;           % also accept this naming
elseif isfield(p,'dCLt_ddeltaE')
    C_m_deltaE = -V_H * eta * p.dCLt_ddeltaE;  % fallback formula, 1/rad
else
    C_m_deltaE = NaN;
end
                                                                                        % ΤΟ esle ΑΝΤΙΣΤΟΙΧΕΙ ΣΤΗΝ 2.45?



% delta_trim simple form [Eq 2.48]
if C_m_deltaE~=0 && ~isnan(C_m_deltaE)
    delta_trim = -(Cm0 + Cm_alpha * p.alpha_trim) / C_m_deltaE;
else
    delta_trim = NaN;
end

% alternative trim with simultaneous CL equations [Eq 2.51]
if isfield(p,'CL_alpha') && isfield(p,'CL_deltaE') && C_m_deltaE~=0
    CL_alpha = p.CL_alpha;
    CL_deltaE = p.CL_deltaE; %#ok<NASGU>
    % solve linear system for alpha_trim and delta_trim if needed:
    % C_L_trim = CL_alpha*alpha_trim + CL_deltaE*delta_trim
    % but keep using given alpha_trim if provided
else
    % leave as computed above or NaN
end

% ---- 3.5 Small disturbance theory: stability derivative estimates (TABLE 3.3) ----
% Note: many derivatives require empirical or aerodynamic inputs. We compute those available.

% Aerodynamic dynamic pressure Q = 0.5*rho*u0^2
Q = 0.5 * p.rho * p.u0^2;

% Non-dimensional coefficients (if provided) convert to dimensional stability derivatives
% Example convert C_* to dimensional X_u etc using formulas in the document (TABLE 3.5)
QS = Q * S;

% Example X_u and X_w [TABLE 3.5]
if isfield(p,'C_Du')
    C_Du = p.C_Du;
else
    C_Du = NaN;
end
X_u = (-(C_Du + 2*p.C_D0) * QS) / (p.m * p.u0);
if isfield(p,'C_Dalpha')
    C_Dalpha = p.C_Dalpha;
else
    C_Dalpha = NaN;
end
X_w = (-(C_Dalpha - CL0) * QS) / (p.m * p.u0);

Z_u = (-(p.C_Lu + 2*CL0) * QS) / (p.m * p.u0);
Z_w = (-(CL_alpha + p.C_D0) * QS) / (p.m * p.u0);
%                                                       
% Longitudinal dynamic-derivative source selection.
% By default, keep the original Nelson-style fallback estimates. For
% aircraft cases with trusted source-table derivatives, such as the B747,
% p.use_direct_longitudinal_dynamic_derivatives can activate direct values.
use_direct_long_dyn = isfield(p,'use_direct_longitudinal_dynamic_derivatives') ...
    && ~isempty(p.use_direct_longitudinal_dynamic_derivatives) ...
    && isscalar(p.use_direct_longitudinal_dynamic_derivatives) ...
    && p.use_direct_longitudinal_dynamic_derivatives;

% Z_wdot / C_Z_alphadot [TABLE 3.5]
% Sign convention:
%   source CL_alphadot > 0  -->  C_Z_alphadot = -CL_alphadot
if use_direct_long_dyn && isfield(p,'C_Z_alphadot') ...
        && ~isempty(p.C_Z_alphadot) && isscalar(p.C_Z_alphadot) && isfinite(p.C_Z_alphadot)

    C_Z_alphadot = p.C_Z_alphadot;
    src_C_Z_alphadot = 'input.C_Z_alphadot';

elseif use_direct_long_dyn && isfield(p,'CL_alphadot') ...
        && ~isempty(p.CL_alphadot) && isscalar(p.CL_alphadot) && isfinite(p.CL_alphadot)

    C_Z_alphadot = -p.CL_alphadot;
    src_C_Z_alphadot = 'input.CL_alphadot converted as C_Z_alphadot=-CL_alphadot';

else
    C_Z_alphadot = -2*eta*CL_at*V_H * dEdalpha;
    src_C_Z_alphadot = 'estimated_tail_formula';
end

Z_wdot = -C_Z_alphadot * c/(2*p.u0) * QS/(p.u0 * p.m);
Z_alpha = p.u0 * Z_wdot;   % dimensional    where Z_alpha=Z_alphadot

% Z_q / C_Z_q [TABLE 3.5]
% Sign convention:
%   source CL_q > 0  -->  C_Z_q = -CL_q
if use_direct_long_dyn && isfield(p,'C_Z_q') ...
        && ~isempty(p.C_Z_q) && isscalar(p.C_Z_q) && isfinite(p.C_Z_q)

    C_Z_q = p.C_Z_q;
    src_C_Z_q = 'input.C_Z_q';

elseif use_direct_long_dyn && isfield(p,'CL_q') ...
        && ~isempty(p.CL_q) && isscalar(p.CL_q) && isfinite(p.CL_q)

    C_Z_q = -p.CL_q;
    src_C_Z_q = 'input.CL_q converted as C_Z_q=-CL_q';

else
    C_Z_q = -2*eta*CL_at*V_H;
    src_C_Z_q = 'estimated_tail_formula';
end

Z_q = -C_Z_q * c/(2*p.u0) * QS / p.m;

% Z_deltaE (dimensional)
% Sign convention:
%   CL_deltaE > 0 means positive elevator deflection increases lift.
%   Body-axis Z is positive downward, so C_Z_deltaE = -CL_deltaE.
%   Once C_Z_deltaE is available, dimensionalize directly with QS/m.
if isfield(p,'C_Z_deltaE') ...
        && ~isempty(p.C_Z_deltaE) && isscalar(p.C_Z_deltaE) && isfinite(p.C_Z_deltaE)

    C_Z_deltaE = p.C_Z_deltaE;
    src_C_Z_deltaE = 'input.C_Z_deltaE';

elseif isfield(p,'CL_deltaE') ...
        && ~isempty(p.CL_deltaE) && isscalar(p.CL_deltaE) && isfinite(p.CL_deltaE)

    C_Z_deltaE = -p.CL_deltaE;
    src_C_Z_deltaE = 'input.CL_deltaE converted as C_Z_deltaE=-CL_deltaE';

elseif isfield(p,'C_L_deltaE') ...
        && ~isempty(p.C_L_deltaE) && isscalar(p.C_L_deltaE) && isfinite(p.C_L_deltaE)

    C_Z_deltaE = -p.C_L_deltaE;
    src_C_Z_deltaE = 'input.C_L_deltaE converted as C_Z_deltaE=-C_L_deltaE';

elseif isfield(p,'C_L_del') ...
        && ~isempty(p.C_L_del) && isscalar(p.C_L_del) && isfinite(p.C_L_del)

    C_Z_deltaE = -p.C_L_del;
    src_C_Z_deltaE = 'input.C_L_del converted as C_Z_deltaE=-C_L_del';

elseif isfield(p,'C_Z_deltaE_non_dim') ...
        && ~isempty(p.C_Z_deltaE_non_dim) && isscalar(p.C_Z_deltaE_non_dim) && isfinite(p.C_Z_deltaE_non_dim)

    C_Z_deltaE = p.C_Z_deltaE_non_dim;
    src_C_Z_deltaE = 'input.C_Z_deltaE_non_dim';

else
    C_Z_deltaE = -p.S_t_ratio * eta * p.dCLt_ddeltaE; % non-dim fallback
    src_C_Z_deltaE = 'estimated_tail_formula_converted_as_Z_force';
end
Z_deltaE = C_Z_deltaE * QS / p.m;                  % possibly needed for B-matrix

% Pitching moment derivatives (dimensional) [TABLE 3.5]
% Non-dimensional Cm derivatives:
%C_m_u = p.C_m_u;  if given as non-dim w.r.t Mach etc
if isfield(p,'C_m_u')
    C_m_u = p.C_m_u;
else
    C_m_u = 0;
end

C_m_alpha = Cm_alpha;

if use_direct_long_dyn && isfield(p,'Cm_alphadot') ...
        && ~isempty(p.Cm_alphadot) && isscalar(p.Cm_alphadot) && isfinite(p.Cm_alphadot)

    C_m_alphadot = p.Cm_alphadot;
    src_C_m_alphadot = 'input.Cm_alphadot';

else
    C_m_alphadot = -2*eta*CL_at*V_H * (lt/c) * dEdalpha; % non-dim
    src_C_m_alphadot = 'estimated_tail_formula';
end

if use_direct_long_dyn && isfield(p,'Cm_q') ...
        && ~isempty(p.Cm_q) && isscalar(p.Cm_q) && isfinite(p.Cm_q)

    C_m_q = p.Cm_q;
    src_C_m_q = 'input.Cm_q';

else
    C_m_q = -2*eta*CL_at*V_H * (lt/c);
    src_C_m_q = 'estimated_tail_formula';
end

% Convert to dimensional derivatives M_* using formulas
M_u = C_m_u * Q * S * c / (p.u0 * p.Iyy);
M_w = C_m_alpha * (Q * S * c) / (p.u0 * p.Iyy);
M_wdot = C_m_alphadot * c/(2*p.u0) * (Q * S * c) / (p.u0 * p.Iyy);
M_alpha = p.u0 * M_w;
M_alpha_dot = p.u0 * M_wdot;
M_q = C_m_q * c/2 * (Q * S * c) / (p.u0 * p.Iyy);

M_deltaE = C_m_deltaE * (Q * S * c) / p.Iyy;


% --- 4.3 Pure pitching motion approximations ---
% Equation: DELTAalpha_dot_dot - (M_q + M_alpha_dot)*DELTAalpha_dot - M_alpha*DELTAalpha = M_deltaE * deltaE
% Compute eigenvalues for short-period approx: lambda^2 - (M_q + M_alpha_dot)*lambda - M_alpha = 0
a2 = 1;
b2 = -(M_q + M_alpha_dot);
c2 = -M_alpha;
lambda_roots = roots([a2 b2 c2]);

% Damping and undamped natural frequency from standard form lambda^2 -2*zeta*wn*lambda + wn^2 = 0
% wn = sqrt(-M_alpha) (from doc)
if M_alpha < 0
    wn = sqrt(-M_alpha);
    zeta = (-(M_q + M_alpha_dot)) / (2*wn);
else
    wn = NaN;
    zeta = NaN;
end

% damped frequency
if ~isnan(wn) && isfinite(wn)
    if zeta >= 0 && zeta < 1
        omega_d = wn * sqrt(1 - zeta^2);   % underdamped oscillation
    else
        omega_d = 0;                       % overdamped/critically damped: no oscillation
    end
else
    omega_d = NaN;
end

% response to elevator step (analytic) [Eq 4.45]
% DELTA_alpha_trim
if M_alpha ~= 0 && isfield(p,'DELTAdelta_e')
    DELTA_alpha_trim = -(M_deltaE * p.DELTAdelta_e)/M_alpha;
else
    DELTA_alpha_trim = NaN;
end

% State-space A and B assembly (4x4) using TABLE 4.53 and 4.54 (note: simplified)
X_u_ = X_u; X_w_ = X_w;
Z_u_ = Z_u; Z_w_ = Z_w;
M_u_ = M_u; M_w_ = M_w; M_q_ = M_q;
Z_w_dot = Z_wdot;   
M_w_dot = M_wdot;   

if isfield(p,'theta0')
    cth0 = cos(p.theta0);
    sth0 = sin(p.theta0);
else
    cth0 = 1;
    sth0 = 0;
end

den = (1 - Z_w_dot);

A = [ X_u_,                 X_w_,                 0,                          -p.g*cth0;
      Z_u_/den,             Z_w_/den,             (p.u0 - Z_q)/den,           -(p.g*sth0)/den;
      M_u_ + (M_w_dot*Z_u_)/den,  M_w_ + (M_w_dot*Z_w_)/den,  M_q_ + (M_w_dot*(p.u0 - Z_q))/den,  -(M_w_dot*p.g*sth0)/den;
      0,                    0,                    1,                           0 ];



B = [ NaN,                      NaN;
      Z_deltaE/den,                  NaN;
      M_deltaE + (M_w_dot*Z_deltaE)/den,   NaN;
      0,                             0 ];

% ---- Dynamic stability assessment via eigenvalues of A ----
if any(isnan(A(:))) || any(~isfinite(A(:)))
    fprintf('Dynamic stability: UNDEFINED (A matrix contains NaN or Inf)\n');
    eigA = NaN(size(A,1),1);
else
    eigA = eig(A);   % eigenvalues λ_i of the system

    maxReal = max(real(eigA));
    tol_dyn = 1e-8;

    if maxReal < -tol_dyn
        fprintf('Dynamic stability: STABLE (all Re(λ) < 0, max Re(λ) = %.6e 1/s)\n', maxReal);
    elseif maxReal > tol_dyn
        fprintf('Dynamic stability: UNSTABLE (max Re(λ) = %.6e 1/s)\n', maxReal);
    else
        fprintf('Dynamic stability: NEUTRAL (max Re(λ) ≈ 0)\n');
    end
end

% ---- Longitudinal mode classification from eigenvalues ----
% Classify response types (aperiodic / oscillatory, stable/unstable/neutral)

if ~any(isnan(eigA(:))) && all(isfinite(eigA(:)))

    eps_im  = 1e-8;   % tolerance for "real" vs "complex"
    eps_eta = 1e-8;   % tolerance for neutral real part

    lamb = eigA(:);

    % ============================================================
    % 1) Separate oscillatory representatives and real roots
    %    For each complex-conjugate pair, keep only the eigenvalue
    %    with positive imaginary part as the representative.
    % ============================================================
    idx_osc  = find(imag(lamb) >  eps_im);
    idx_real = find(abs(imag(lamb)) <= eps_im);

    % Sort oscillatory modes by |Im(lambda)| descending (fastest first)
    if ~isempty(idx_osc)
        [~, ord_osc] = sort(abs(imag(lamb(idx_osc))), 'descend');
        idx_osc = idx_osc(ord_osc);
    end

    % Sort real modes by |Re(lambda)| descending (fastest decay/growth first)
    if ~isempty(idx_real)
        [~, ord_real] = sort(abs(real(lamb(idx_real))), 'descend');
        idx_real = idx_real(ord_real);
    end

    % ============================================================
    % 2) Build oscillatory mode table
    % ============================================================
    oscModes = struct('name', {}, ...
                      'eta', {}, ...
                      'omega_d', {}, ...
                      'omega_n', {}, ...
                      'zeta', {}, ...
                      'response', {}, ...
                      'damping', {}, ...
                      'classification_note', {});

    for k = 1:numel(idx_osc)
        i = idx_osc(k);

        eta_i     = real(lamb(i));
        omega_d_i = abs(imag(lamb(i)));
        omega_n_i = sqrt(eta_i^2 + omega_d_i^2);

        if omega_n_i > 0
            zeta_i = -eta_i / omega_n_i;
        else
            zeta_i = NaN;
        end

        if eta_i < -eps_eta
            resp_i = 'Stable Decaying Oscillation';
        elseif eta_i > eps_eta
            resp_i = 'Unstable Growing Oscillation';
        else
            resp_i = 'Undamped (Neutral) Oscillation';
        end

        damp_i = '';
        if eta_i < -eps_eta && isfinite(zeta_i)
            if zeta_i < 0.10
                damp_i = 'Very Lightly Damped';
            elseif zeta_i < 0.30
                damp_i = 'Lightly Damped';
            elseif zeta_i < 0.70
                damp_i = 'Moderately Damped';
            elseif zeta_i < 1.00
                damp_i = 'Heavily Damped';
            else
                damp_i = 'Near aperiodic limit (ζ ≥ 1)';
            end
        end

        oscModes(end+1).name = sprintf('Oscillatory mode %d', k); %#ok<AGROW>
        oscModes(end).eta = eta_i;
        oscModes(end).omega_d = omega_d_i;
        oscModes(end).omega_n = omega_n_i;
        oscModes(end).zeta = zeta_i;
        oscModes(end).response = resp_i;
        oscModes(end).damping = damp_i;
        oscModes(end).classification_note = '';
    end

    % ============================================================
    % 3) Build aperiodic (real-root) mode table
    % ============================================================
    realModes = struct('name', {}, ...
                       'eta', {}, ...
                       'response', {}, ...
                       'classification_note', {});

    for k = 1:numel(idx_real)
        i = idx_real(k);
        eta_i = real(lamb(i));

        if eta_i < -eps_eta
            resp_i = 'Stable Aperiodic (Decaying Exponential / Subsidence)';
        elseif eta_i > eps_eta
            resp_i = 'Unstable Aperiodic (Growing Exponential / Divergence)';
        else
            resp_i = 'Neutral Aperiodic (η ≈ 0)';
        end

        realModes(end+1).name = sprintf('Aperiodic mode %d', k); %#ok<AGROW>
        realModes(end).eta = eta_i;
        realModes(end).response = resp_i;
        realModes(end).classification_note = '';
    end

    % ============================================================
    % 4) Interpret longitudinal mode structure without overclaiming
    % ============================================================
    modeSummary = struct();
    modeSummary.num_oscillatory_pairs = numel(oscModes);
    modeSummary.num_aperiodic_modes   = numel(realModes);
    modeSummary.classical_case        = false;
    modeSummary.note                  = '';

    if numel(oscModes) == 2
        % Classical case:
        % higher |Im(lambda)| -> short-period
        % lower  |Im(lambda)| -> phugoid
        oscModes(1).name = 'Short-period';
        oscModes(1).classification_note = ...
            'Assigned by higher oscillation frequency among two oscillatory pairs.';
        oscModes(2).name = 'Phugoid';
        oscModes(2).classification_note = ...
            'Assigned by lower oscillation frequency among two oscillatory pairs.';

        modeSummary.classical_case = true;
        modeSummary.note = ...
            'Classical longitudinal structure detected: two oscillatory pairs.';

    elseif isscalar(oscModes) && numel(realModes) == 2
        % Mixed case:
        % one oscillatory pair + two real roots
        % infer likely identity from timescale separation

        wd_osc = oscModes(1).omega_d;
        real_rates = abs([realModes.eta]);
        min_real_rate = min(real_rates);

        % If the oscillatory mode is slower than the real modes, treat it as phugoid-like.
        % Otherwise, treat it as short-period-like.
        if wd_osc < min_real_rate
            oscModes(1).name = 'Phugoid-like oscillation';
            oscModes(1).classification_note = ...
                ['Single oscillatory pair is slower than the real modes; ' ...
                 'interpreted as phugoid-like. The real roots may represent an ' ...
                 'overdamped short-period-type response.'];
            modeSummary.note = ...
                ['One oscillatory pair and two real roots detected. ' ...
                 'The oscillatory pair is slower than the real modes, so it is ' ...
                 'interpreted as phugoid-like.'];
        else
            oscModes(1).name = 'Short-period-like oscillation';
            oscModes(1).classification_note = ...
                ['Single oscillatory pair is not slower than the real modes; ' ...
                 'interpreted as short-period-like by timescale comparison.'];
            modeSummary.note = ...
                ['One oscillatory pair and two real roots detected. ' ...
                 'The oscillatory pair is interpreted as short-period-like by ' ...
                 'timescale comparison.'];
        end

        for k = 1:numel(realModes)
            if realModes(k).eta < -eps_eta
                realModes(k).name = sprintf('Aperiodic decaying mode %d', k);
                realModes(k).classification_note = ...
                    'Real negative root: decaying exponential (subsidence).';
            elseif realModes(k).eta > eps_eta
                realModes(k).name = sprintf('Aperiodic growing mode %d', k);
                realModes(k).classification_note = ...
                    'Real positive root: growing exponential (divergence).';
            else
                realModes(k).name = sprintf('Aperiodic neutral mode %d', k);
                realModes(k).classification_note = ...
                    'Real root near zero: neutral aperiodic response.';
            end
        end

    elseif numel(oscModes) == 0 && numel(realModes) == 4
        modeSummary.note = ...
            ['All four longitudinal roots are real. The response is entirely ' ...
             'aperiodic; no oscillatory short-period/phugoid pair is present.'];

        for k = 1:numel(realModes)
            if realModes(k).eta < -eps_eta
                realModes(k).name = sprintf('Aperiodic decaying mode %d', k);
                realModes(k).classification_note = ...
                    'Real negative root: decaying exponential (subsidence).';
            elseif realModes(k).eta > eps_eta
                realModes(k).name = sprintf('Aperiodic growing mode %d', k);
                realModes(k).classification_note = ...
                    'Real positive root: growing exponential (divergence).';
            else
                realModes(k).name = sprintf('Aperiodic neutral mode %d', k);
                realModes(k).classification_note = ...
                    'Real root near zero: neutral aperiodic response.';
            end
        end

    elseif isscalar(oscModes)
        oscModes(1).name = 'Oscillatory mode 1';
        oscModes(1).classification_note = ...
            'Single oscillatory pair detected; short-period/phugoid-like identification is ambiguous.';
        modeSummary.note = ...
            'Only one oscillatory pair detected; generic oscillatory naming retained.';

        for k = 1:numel(realModes)
            if realModes(k).eta < -eps_eta
                realModes(k).name = sprintf('Aperiodic decaying mode %d', k);
                realModes(k).classification_note = ...
                    'Real negative root: decaying exponential (subsidence).';
            elseif realModes(k).eta > eps_eta
                realModes(k).name = sprintf('Aperiodic growing mode %d', k);
                realModes(k).classification_note = ...
                    'Real positive root: growing exponential (divergence).';
            else
                realModes(k).name = sprintf('Aperiodic neutral mode %d', k);
                realModes(k).classification_note = ...
                    'Real root near zero: neutral aperiodic response.';
            end
        end

    elseif numel(oscModes) == 0
        modeSummary.note = ...
            'No oscillatory longitudinal pairs detected. All identified modes are aperiodic.';

        for k = 1:numel(realModes)
            if realModes(k).eta < -eps_eta
                realModes(k).name = sprintf('Aperiodic decaying mode %d', k);
                realModes(k).classification_note = ...
                    'Real negative root: decaying exponential (subsidence).';
            elseif realModes(k).eta > eps_eta
                realModes(k).name = sprintf('Aperiodic growing mode %d', k);
                realModes(k).classification_note = ...
                    'Real positive root: growing exponential (divergence).';
            else
                realModes(k).name = sprintf('Aperiodic neutral mode %d', k);
                realModes(k).classification_note = ...
                    'Real root near zero: neutral aperiodic response.';
            end
        end

    else
        modeSummary.note = ...
            ['More than two oscillatory pairs detected. This is outside the ' ...
             'standard 4-state longitudinal picture; generic naming is retained.'];

        for k = 1:numel(oscModes)
            oscModes(k).name = sprintf('Oscillatory mode %d', k);
            oscModes(k).classification_note = ...
                'Generic oscillatory label retained; unusual oscillatory mode count.';
        end

        for k = 1:numel(realModes)
            if realModes(k).eta < -eps_eta
                realModes(k).name = sprintf('Aperiodic decaying mode %d', k);
                realModes(k).classification_note = ...
                    'Real negative root: decaying exponential (subsidence).';
            elseif realModes(k).eta > eps_eta
                realModes(k).name = sprintf('Aperiodic growing mode %d', k);
                realModes(k).classification_note = ...
                    'Real positive root: growing exponential (divergence).';
            else
                realModes(k).name = sprintf('Aperiodic neutral mode %d', k);
                realModes(k).classification_note = ...
                    'Real root near zero: neutral aperiodic response.';
            end
        end
    end

    % ============================================================
    % 5) Print summary
    % ============================================================
    fprintf('\n---- Longitudinal mode classification ----\n');
    fprintf('Oscillatory pairs detected: %d\n', numel(oscModes));
    fprintf('Aperiodic modes detected : %d\n', numel(realModes));
    fprintf('%s\n', modeSummary.note);

    if ~isempty(oscModes)
        fprintf('\nOSCILLATORY MODES:\n');
        for j = 1:numel(oscModes)
            if oscModes(j).eta < -eps_eta
                fprintf('  %-28s: %s', oscModes(j).name, oscModes(j).response);
                if ~isempty(oscModes(j).damping)
                    fprintf(' (%s, ζ=%.3f, ω_n=%.3f rad/s, ω_d=%.3f rad/s)', ...
                        oscModes(j).damping, oscModes(j).zeta, ...
                        oscModes(j).omega_n, oscModes(j).omega_d);
                else
                    fprintf(' (ζ=%.3f, ω_n=%.3f rad/s, ω_d=%.3f rad/s)', ...
                        oscModes(j).zeta, oscModes(j).omega_n, oscModes(j).omega_d);
                end
                fprintf('\n');
            else
                fprintf('  %-28s: %s (η=%.3e 1/s, ω_d=%.3f rad/s', ...
                    oscModes(j).name, oscModes(j).response, ...
                    oscModes(j).eta, oscModes(j).omega_d);
                if isfinite(oscModes(j).zeta)
                    fprintf(', ζ=%.3f', oscModes(j).zeta);
                end
                fprintf(')\n');
            end

            if ~isempty(oscModes(j).classification_note)
                fprintf('    note: %s\n', oscModes(j).classification_note);
            end
        end
    end

    if ~isempty(realModes)
        fprintf('\nAPERIODIC MODES:\n');
        for j = 1:numel(realModes)
            fprintf('  %-28s: η=%.3e 1/s  -> %s\n', ...
                realModes(j).name, realModes(j).eta, realModes(j).response);

            if ~isempty(realModes(j).classification_note)
                fprintf('    note: %s\n', realModes(j).classification_note);
            end
        end
    end

    % ============================================================
    % 6) Store in outputs
    % ============================================================
    out.modes.oscillatory = oscModes;
    out.modes.aperiodic   = realModes;
    out.modes.summary     = modeSummary;
end

% Package outputs
% -------------------------------------------------------------------------
% Compatibility outputs
% -------------------------------------------------------------------------
% These fields preserve the original flat output interface used by existing
% scripts and the combined runner/export workflow.
out.Cm_alpha = Cm_alpha;
out.Cm0 = Cm0;
out.x_NP = x_NP;
out.C_m_deltaE = C_m_deltaE;
out.delta_trim = delta_trim;
out.X_u = X_u; out.X_w = X_w;
out.Z_u = Z_u; out.Z_w = Z_w; out.Z_wdot = Z_wdot;
out.Z_alpha  = Z_alpha;
out.Z_q      = Z_q;
out.Z_deltaE = Z_deltaE;
out.M_deltaE = M_deltaE;
out.M_u = M_u; out.M_w = M_w; out.M_q = M_q; out.M_alpha = M_alpha; out.M_alpha_dot = M_alpha_dot;
out.lambda_roots = lambda_roots;
out.wn = wn; out.zeta = zeta; out.omega_d = omega_d;
out.eigA = eigA;
out.A = A; out.B = B;
out.DELTA_alpha_trim = DELTA_alpha_trim;

% -------------------------------------------------------------------------
% Grouped outputs
% -------------------------------------------------------------------------
% These grouped fields mirror the organization used in the lateral analysis
% while keeping all original flat fields above unchanged.
out.meta = struct();
out.meta.file = mfilename;
out.meta.units = 'SI';
out.meta.analysis = 'longitudinal';
out.meta.notes = ['Grouped fields are added for readability; original ', ...
                  'flat fields are retained for backward compatibility.'];

out.flight_condition = struct();
out.flight_condition.rho = p.rho;
out.flight_condition.u0 = p.u0;
out.flight_condition.qbar = Q;
out.flight_condition.g = p.g;
out.flight_condition.m = p.m;
if isfield(p,'theta0')
    out.flight_condition.theta0 = p.theta0;
else
    out.flight_condition.theta0 = 0;
end

out.geometry = struct();
out.geometry.S = S;
out.geometry.St = St;
out.geometry.c_bar = c;
out.geometry.lt = lt;
out.geometry.x_cg = x_cg;
out.geometry.x_ac = x_ac;
out.geometry.V_H = V_H;
out.geometry.S_t_ratio = p.S_t_ratio;

out.inertia = struct();
out.inertia.Iyy = p.Iyy;

out.nondim = struct();
out.nondim.CL0 = CL0;
out.nondim.CL_alpha = CL_alpha;
out.nondim.CL_alpha_w = CL_aw;
out.nondim.CL_alpha_t = CL_at;
out.nondim.Cm_alpha = Cm_alpha;
out.nondim.Cm0 = Cm0;
out.nondim.C_m_deltaE = C_m_deltaE;
out.nondim.C_D0 = p.C_D0;
out.nondim.C_Du = C_Du;
out.nondim.C_Dalpha = C_Dalpha;
out.nondim.C_Z_alphadot = C_Z_alphadot;
out.nondim.C_Z_q = C_Z_q;
out.nondim.C_Z_deltaE = C_Z_deltaE;
out.nondim.C_m_u = C_m_u;
out.nondim.C_m_alphadot = C_m_alphadot;
out.nondim.C_m_q = C_m_q;

out.derivative_sources = struct();
out.derivative_sources.use_direct_longitudinal_dynamic_derivatives = use_direct_long_dyn;
out.derivative_sources.C_Z_alphadot = src_C_Z_alphadot;
out.derivative_sources.C_Z_q = src_C_Z_q;
out.derivative_sources.C_Z_deltaE = src_C_Z_deltaE;
out.derivative_sources.C_m_alphadot = src_C_m_alphadot;
out.derivative_sources.C_m_q = src_C_m_q;

out.static_stability = struct();
out.static_stability.Cm_alpha = Cm_alpha;
out.static_stability.Cm0 = Cm0;
out.static_stability.dCm_dCL = dCm_dCL;
out.static_stability.x_NP = x_NP;
out.static_stability.x_NP_by_c = x_NP_by_c;
out.static_stability.x_NP_from_Cm_alpha = x_NP_from_Cm_alpha;
out.static_stability.x_NP_by_c_from_Cm_alpha = x_NP_by_c_from_Cm_alpha;
out.static_stability.static_margin = SM;
out.static_stability.static_margin_from_neutral_point = SM;
out.static_stability.static_margin_from_Cm_alpha = SM_from_Cm_alpha;
out.static_stability.static_margin_estimate_range = SM_estimate_range;
out.static_stability.static_margin_primary_source = 'neutral_point_Eq_2_36';
out.static_stability.static_margin_secondary_source = '-Cm_alpha/CL_alpha';
out.static_stability.static_margin_note = static_margin_note;
out.static_stability.condition = 'dCm/dCL < 0 and positive static margin';

out.trim = struct();
out.trim.C_m_deltaE = C_m_deltaE;
out.trim.delta_trim = delta_trim;
out.trim.DELTA_alpha_trim = DELTA_alpha_trim;

out.dimensional = struct();
out.dimensional.X_u = X_u;
out.dimensional.X_w = X_w;
out.dimensional.Z_u = Z_u;
out.dimensional.Z_w = Z_w;
out.dimensional.Z_wdot = Z_wdot;
out.dimensional.Z_alpha = Z_alpha;
out.dimensional.Z_q = Z_q;
out.dimensional.Z_deltaE = Z_deltaE;
out.dimensional.M_u = M_u;

% M_w is computed internally in SI units, 1/(m*s), because this core runs in SI.
% Teper/Nelson report M_w in AVS/body-axis units, 1/(ft*s).
% Preserve the raw SI value, but expose out.dimensional.M_w in the Teper-comparable basis.
out.dimensional.M_w_raw_SI = M_w;
out.dimensional.M_w = M_w / 3.28083989501312;

out.dimensional.M_wdot = M_wdot;
out.dimensional.M_q = M_q;
out.dimensional.M_alpha = M_alpha;
out.dimensional.M_alpha_dot = M_alpha_dot;
out.dimensional.M_deltaE = M_deltaE;

out.state_space = struct();
out.state_space.state_vector = {'Delta_u','Delta_w','Delta_q','Delta_theta'};
out.state_space.control_vector = {'Delta_delta_e','unused_second_input'};
out.state_space.A = A;
out.state_space.B = B;
out.state_space.eigenvalues = eigA;

out.approx = struct();

% -------------------------------------------------------------------------
% Approximate short-period mode
% -------------------------------------------------------------------------
out.approx.short_period = struct();
out.approx.short_period.method = ...
    'Nelson pure-pitching short-period approximation';
out.approx.short_period.characteristic_polynomial = [a2, b2, c2];
out.approx.short_period.eigenvalues = lambda_roots;
out.approx.short_period.wn = wn;
out.approx.short_period.zeta = zeta;
out.approx.short_period.omega_d = omega_d;

if isfinite(omega_d) && omega_d > 0
    out.approx.short_period.period = 2*pi/omega_d;
else
    out.approx.short_period.period = NaN;
end

if isfinite(lambda_roots(1)) && real(lambda_roots(1)) < 0
    out.approx.short_period.t_half = log(2)/abs(real(lambda_roots(1)));
else
    out.approx.short_period.t_half = NaN;
end

if isfinite(out.approx.short_period.period) && out.approx.short_period.period > 0 ...
        && isfinite(out.approx.short_period.t_half)
    out.approx.short_period.N_half = ...
        out.approx.short_period.t_half / out.approx.short_period.period;
else
    out.approx.short_period.N_half = NaN;
end

% -------------------------------------------------------------------------
% Approximate phugoid / long-period mode
% -------------------------------------------------------------------------
% Reduced-order phugoid approximation from the full longitudinal A matrix.
%
% State order in the current longitudinal core:
%   x = [Delta_u; Delta_w; Delta_q; Delta_theta]
%
% Slow states retained:
%   [Delta_u; Delta_theta]
%
% Fast states eliminated quasi-steadily:
%   [Delta_w; Delta_q]
%
% A_phugoid_reduced = A_ss - A_sf*(A_ff\A_fs)
out.approx.phugoid = struct();
out.approx.phugoid.method = ...
    'Reduced-order phugoid approximation from full A matrix using quasi-steady elimination of Delta_w and Delta_q';
out.approx.phugoid.retained_states = {'Delta_u','Delta_theta'};
out.approx.phugoid.eliminated_states = {'Delta_w','Delta_q'};

if exist('A','var') && isnumeric(A) && isequal(size(A), [4 4]) && all(isfinite(A(:)))

    ph_slow_idx = [1 4];
    ph_fast_idx = [2 3];

    A_ss_ph = A(ph_slow_idx, ph_slow_idx);
    A_sf_ph = A(ph_slow_idx, ph_fast_idx);
    A_fs_ph = A(ph_fast_idx, ph_slow_idx);
    A_ff_ph = A(ph_fast_idx, ph_fast_idx);

    if rcond(A_ff_ph) >= 1.0e-12

        A_phugoid_reduced = A_ss_ph - A_sf_ph * (A_ff_ph \ A_fs_ph);
        eig_phugoid_approx = eig(A_phugoid_reduced);

        % Pick one representative eigenvalue for scalar modal metrics.
        % If the approximation is oscillatory, use the positive-imaginary root.
        % If it is aperiodic, use the root with the smaller absolute real part.
        idx_ph_complex = find(imag(eig_phugoid_approx) > 1.0e-8);

        if ~isempty(idx_ph_complex)
            [~, local_idx_ph] = min(abs(imag(eig_phugoid_approx(idx_ph_complex))));
            idx_ph_rep = idx_ph_complex(local_idx_ph);
        else
            [~, idx_ph_rep] = min(abs(real(eig_phugoid_approx)));
        end

        lambda_phugoid_approx = eig_phugoid_approx(idx_ph_rep);

        eta_phugoid_approx = real(lambda_phugoid_approx);
        omega_d_phugoid_approx = abs(imag(lambda_phugoid_approx));
        omega_n_phugoid_approx = sqrt(eta_phugoid_approx^2 + omega_d_phugoid_approx^2);

        if omega_n_phugoid_approx > 0
            zeta_phugoid_approx = -eta_phugoid_approx / omega_n_phugoid_approx;
        else
            zeta_phugoid_approx = NaN;
        end

        if omega_d_phugoid_approx > 0
            period_phugoid_approx = 2*pi / omega_d_phugoid_approx;
        else
            period_phugoid_approx = NaN;
        end

        if eta_phugoid_approx < 0
            t_half_phugoid_approx = log(2) / abs(eta_phugoid_approx);
        else
            t_half_phugoid_approx = NaN;
        end

        if isfinite(period_phugoid_approx) && period_phugoid_approx > 0 ...
                && isfinite(t_half_phugoid_approx)
            N_half_phugoid_approx = t_half_phugoid_approx / period_phugoid_approx;
        else
            N_half_phugoid_approx = NaN;
        end

        if eta_phugoid_approx < -1.0e-8 && omega_d_phugoid_approx > 1.0e-8
            response_phugoid_approx = 'Stable Decaying Oscillation';
        elseif eta_phugoid_approx > 1.0e-8 && omega_d_phugoid_approx > 1.0e-8
            response_phugoid_approx = 'Unstable Growing Oscillation';
        elseif abs(eta_phugoid_approx) <= 1.0e-8 && omega_d_phugoid_approx > 1.0e-8
            response_phugoid_approx = 'Undamped Neutral Oscillation';
        elseif eta_phugoid_approx < -1.0e-8
            response_phugoid_approx = 'Stable Aperiodic Decay';
        elseif eta_phugoid_approx > 1.0e-8
            response_phugoid_approx = 'Unstable Aperiodic Divergence';
        else
            response_phugoid_approx = 'Neutral Aperiodic Response';
        end

        damping_phugoid_approx = '';
        if eta_phugoid_approx < -1.0e-8 && isfinite(zeta_phugoid_approx)
            if zeta_phugoid_approx < 0.10
                damping_phugoid_approx = 'Very Lightly Damped';
            elseif zeta_phugoid_approx < 0.30
                damping_phugoid_approx = 'Lightly Damped';
            elseif zeta_phugoid_approx < 0.70
                damping_phugoid_approx = 'Moderately Damped';
            elseif zeta_phugoid_approx < 1.00
                damping_phugoid_approx = 'Heavily Damped';
            else
                damping_phugoid_approx = 'Near aperiodic limit (zeta >= 1)';
            end
        end

        out.approx.phugoid.A_reduced = A_phugoid_reduced;
        out.approx.phugoid.eigenvalues = eig_phugoid_approx;
        out.approx.phugoid.representative_eigenvalue = lambda_phugoid_approx;
        out.approx.phugoid.eta = eta_phugoid_approx;
        out.approx.phugoid.omega_d = omega_d_phugoid_approx;
        out.approx.phugoid.omega_n = omega_n_phugoid_approx;
        out.approx.phugoid.zeta = zeta_phugoid_approx;
        out.approx.phugoid.period = period_phugoid_approx;
        out.approx.phugoid.t_half = t_half_phugoid_approx;
        out.approx.phugoid.N_half = N_half_phugoid_approx;
        out.approx.phugoid.response = response_phugoid_approx;
        out.approx.phugoid.damping = damping_phugoid_approx;
        out.approx.phugoid.status = 'computed';

    else
        out.approx.phugoid.A_reduced = NaN(2,2);
        out.approx.phugoid.eigenvalues = [NaN; NaN];
        out.approx.phugoid.representative_eigenvalue = NaN;
        out.approx.phugoid.eta = NaN;
        out.approx.phugoid.omega_d = NaN;
        out.approx.phugoid.omega_n = NaN;
        out.approx.phugoid.zeta = NaN;
        out.approx.phugoid.period = NaN;
        out.approx.phugoid.t_half = NaN;
        out.approx.phugoid.N_half = NaN;
        out.approx.phugoid.response = 'Undefined';
        out.approx.phugoid.damping = '';
        out.approx.phugoid.status = 'not computed';
        out.approx.phugoid.reason = 'Fast-state block A_ff is nearly singular.';
    end

else
    out.approx.phugoid.A_reduced = NaN(2,2);
    out.approx.phugoid.eigenvalues = [NaN; NaN];
    out.approx.phugoid.representative_eigenvalue = NaN;
    out.approx.phugoid.eta = NaN;
    out.approx.phugoid.omega_d = NaN;
    out.approx.phugoid.omega_n = NaN;
    out.approx.phugoid.zeta = NaN;
    out.approx.phugoid.period = NaN;
    out.approx.phugoid.t_half = NaN;
    out.approx.phugoid.N_half = NaN;
    out.approx.phugoid.response = 'Undefined';
    out.approx.phugoid.damping = '';
    out.approx.phugoid.status = 'not computed';
    out.approx.phugoid.reason = 'Full longitudinal A matrix is missing, nonnumeric, wrong size, or nonfinite.';
end

out.modes_exact = struct();
out.modes_exact.eigenvalues = eigA;
if isfield(out,'modes')
    out.modes_exact.classification = out.modes;
end

end
