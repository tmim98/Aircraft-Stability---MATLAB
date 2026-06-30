
%Linearized Rigid Body Equations Of Motion TABLE 3.2 Nelson %

% X %
syms dPROSdt X_u Deltau X_w Deltaw g theta_0 Deltatheta X_delta_e Deltadelta_e X_delta_T Deltadelta_T 
(dPROSdt-X_u)*Deltau -X_w*Deltaw + g*cos(theta_0)*Deltatheta == X_delta_e*Deltadelta_e + X_delta_T*Deltadelta_T;

% Z %
syms Z_u Z_wdot Z_w u_0 Z_q Z_delta_e Z_delta_T 
-Z_u*Deltau +(((1-Z_wdot)*dPROSdt)-Z_w)*Deltaw - (((u_0-Z_q)*dPROSdt)-g*(sin(theta_0)))*Deltatheta == Z_delta_e*Deltadelta_e + Z_delta_T*Deltadelta_T;

% M %

syms M_u M_wdot M_w d2PROSdt2 M_q M_delta_e M_delta_T

-M_u*Deltau - (M_wdot*dPROSdt + M_w)*Deltaw + (d2PROSdt2-M_q*d2PROSdt2)*Deltatheta == M_delta_e*Deltadelta_e + M_delta_T*Deltadelta_T;

% Equations for estimating longitudinal stability coefficients TABLE 3.3 %

% X-Force Derivatives %

syms C_X_u C_D_u C_D_0 C_T_u C_X_alpha C_L_0 C_L_alpha

C_X_u == -(C_D_u+2*C_D_0)+ C_T_u;

C_X_alpha == C_L_0 -(((2*C_L_0)/(pi*epsilon))*(C_L_alpha/AR));

% Z-Force Derivatives %

syms C_Z_u C_Z_alpha C_Z_alphadot C_Z_q C_Z_delta_e Mach C_L_delta_e dC_L_tPROSddelta_e

C_Z_u == -((Mach^2)/(1-Mach^2))*C_L_0 - 2*C_L_0;

C_Z_alpha == -(C_L_alpha + C_D_0);

C_Z_alphadot == -2*heta*C_L_alpha_t*V_H*MerikhEpsilon_uProsAlpha;

C_Z_q ==  -2*heta*C_L_alpha_t*V_H;

C_Z_delta_e == -(S_t/S)*heta*MerikhEpsilon_uProsAlpha*dC_L_tPROSddelta_e;
% C_Z_delta_e == -C_L_delta_e %

% Pitching Moment Derivatives % 

syms C_m_u C_m_alphadot C_m_q C_m_delta_e MerikhC_mPROSMach Mach0 

C_m_u == MerikhC_mPROSMach*Mach0;

% C_m_alpha == C_m_alpha_f - C_L_alpha_w*(x_ac/cbar - x_cg/cbar) - (C_L_alpha_t*S_t*V_t^2*V_w^2*l_t*rDens^2)/(S*cbar) %

C_m_alphadot == -2*heta*C_L_alpha_t*V_H*(l_t/cbar)*MerikhEpsilon_uProsAlpha;

C_m_q = -2*heta*C_L_alpha_t*V_H*(l_t/cbar);

C_m_delta_e == -heta*V_H*dC_L_tPROSddelta_e;


% Summary Of Longitudinal Derivativatives %

syms Q C_D_alpha m C_L_u c Z_alpha Z_alphadot M_alpha M_alphadot I_y b
X_u = -((C_D_u + 2*C_D_0)*Q*S)/(m*u_0);

X_w == -((C_L_u + 2*C_L_0)*Q*S)/(m*u_0);


Z_u == -((C_D_u + 2*C_L_0)*Q*S)/(m*u_0);

Z_w == -((C_L_alpha + 2*C_D_0)*Q*S)/(m*u_0);

Z_wdot == -C_Z_alphadot*((c*Q*S)/(2*m*u_0^2));

Z_alpha == u_0*Z_wdot; % ==Z_alphadot (is it though?%

Z_q == -C_Z_q*((c*Q*S)/(2*u_0*m));

Z_delta_e == -C_Z_delta_e*Q*S/m;


M_u == C_m_u*((Q*S*c)/u_0*I_y);

M_w == C_m_alpha*((Q*S*cbar)/u_0*I_y);

M_wdot == C_m_alphadot*(cbar/2*u_0)*((Q*S*cbar)/u_0*I_y);

M_alpha == u_0*M_w;

M_alphadot  == u_0*M_wdot;

M_q == C_m_q*(cbar/2*u_0)*((Q*S*cbar)/I_y);

M_delta_e == C_m_delta_e*((Q*S*cbar)/I_y);
