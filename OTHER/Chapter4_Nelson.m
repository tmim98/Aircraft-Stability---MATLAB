 % Pure Pitching Motion 4.3 %

syms Deltaalphadotdot Deltaalphadot Deltaalpha Deltadelta_e M__q M__alphadot M__alpha M__delta_e dMdq dMdalphadot dMdalpha dMddelta_e lamda zeta omega_n omega hetaReal PhaseAgnle

Deltaalphadotdot-(M__q+M__alphadot)*Deltaalphadot-M__alpha*Deltaalpha == M__delta_e*Deltadelta_e;

% where %
% M__q=dMdq/I_y %
% M__alphadot=dMdalphadot/I_y %
% M__alpha=dMdalpha/I_y %
% M__detla_e=dMddelta_e/I_y %

lamda^2 -(M__q + M__alphadot)/lamda-M__alpha == 0; % Characteristic Eq %
lamda^2 - 2*zeta*omega_n*lamda + omega_n^2 == 0;
omega_n==sqrt(-M__alpha);
zeta== -(M__q + M__alphadot)/2*sqrt(-M__alpha);
%lamda == hetaREal +- 1i*omega;%
omega == omega_n*sqrt(1-zeta^2);

syms Deltaalpha_trim t

Deltaalpha_trim == -M__delta_e*Deltadelta_e/M__alpha;
Deltaalpha == Deltaalpha_trim*(1+((exp(-zeta*omega_n*t)/sqrt(1-zeta^2))*sin(sqrt(1-zeta^2)*omega_n*t+PhaseAgnle)));

syms t_double N_double

t_double == 0.693/abs(hetaReal);
N_double == 0.110*(abs(omega/hetaReal));

syms xStateVector xStateVectordot AStateVec BStateVec hetaControlVector Deltaq DeltaTheta Deltadelta X_delta Z_delta M_delta lambda_r

xStateVectordot = [Deltau; Deltaw; Deltaq; DeltaTheta];
hetaControlVector = [Deltadelta; Deltadelta_T];
AStateVec = [X_u X_w 0 -g; Z_u Z_w u_0 0; M_u+M_wdot*Z_u M_w+M_wdot*Z_w M_q+M_wdot*u_0 0; 0 0 1 0];
BStateVec = [X_delta X_delta_T; Z_delta Z_delta_T; M_delta+M_wdot*Z_delta M_delta_T+M_wdot*Z_delta_T];

det(lambda_r*eye(4)-AStateVec)==0;
 
syms omega_n_p zeta_p omega_n_sp zeta_sp

% Long Period (Phygoid) Approximations % 
omega_n_p == sqrt(-Z_u*g/u_0);
zeta_p == -X_u/2*omega_n_p;

% Short Period Approximations %

omega_n_sp == sqrt((Z_alpha*M_q/u_0)-M_alpha);
zeta_sp == ((M_q+M_alphadot+(Z_alpha/u_0))/-2*omega_n_sp);
