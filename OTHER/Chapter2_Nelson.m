syms C_L C_m alpha 

%C_m_alpha = diff(C_m,alpha);% 
%C_m_alpha= diff(C_m,alpha) = (diff(C_m,C_L)*diff(C_L,alpha));%

%Static Stability Conditions:%
%1) diff(C_m,alpha) <= 0 %
%2) diff(C_m,C_L)>=0 %

% Wing Contribution %
syms C_m_ac_w C_L_0_w x_cg x_ac cbar C_L_alpha_w 

C_m_0_w = C_m_ac_w + C_L_0_w*((x_cg/cbar)-(x_ac/cbar));
C_m_alpha_w = C_L_alpha_w*((x_cg/cbar)-(x_ac/cbar));

% Tail Contribution %

syms C_L_w heta S_t S C_L_t V_t V_w Q_t Q_w AR l_t C_m_alpha epsilon C_m_0 C_L_alpha_t epsilon_0 i_w i_t Rw rDens
% epsilon = Downwash angle %

%Genika : C_L = C_L_w + heta*(S_t/S)*C_L_t % % rDens = density %

heta = (.5*rDens*V_t^2/.5*rDens*V_w^2); 
% heta = (.5*rDens*V_t^2/.5*rDens*V_w^2) = Q_t/Q_w ; %
% Tail Efficiency between 0.8-1.2 %
V_H = (l_t*S_t)/(S*cbar);
epsilon = (2*C_L_w)/(pi*AR*Rw);
epsilon_alpha = diff(epsilon,alpha);
% epsilon alpha = diff(epsilon,alpha) = (2*C_L_alpha_w)/(pi*AR*Rw); %
C_m_cg_t = C_m_0 + C_m_alpha*alpha;
C_m_0_t = heta*V_H*C_L_alpha_t/(epsilon_0+i_w-i_t);
C_m_alhpa_t = -heta*V_H*C_L_alpha_t*(1-epsilon_alpha);

% Fuselage Contribution %

syms l_f MerikhEpsilon_uProsAlpha deltaChi
% d-e_u/d-alpha Figure 2.13 Nelson% 
% deltaChi=length of fuselage increments%

% Equation 2.32 mmissing, look comment @ Nelson  % 

syms C_m_cg C_m_0_f C_m_alpha_f

C_m_cg = C_m_0 +C_m_alpha*alpha;
C_m_0 = C_m_0_w + C_m_0_f + heta*V_H*C_L_alpha_t*(epsilon_0+i_w-i_t);
C_m_alpha = C_L_alpha_w*((x_cg/cbar)-(x_ac/cbar)) + C_m_alpha_f- heta*V_H*C_L_alpha_t*(1-epsilon_alpha);

% Stick Fixed Neutral Point %

syms X_NP

X_NP = (x_ac/cbar) - (C_m_alpha_f/C_L_alpha_w)+heta*V_H*(C_L_alpha_t/C_L_alpha_w)*(1-epsilon_alpha);

% Elevator Effectiveness %

syms DeltaC_m delta_e C_m_delta_e DeltaC_L delta_trim alpha_trim C_L_alpha C_L_trim x_NP_tonos C_L_alpha_t_tonosStoC 

%DeltaC_m = C_m_delta_e*delta_e;%
% C_m_delta_e = diff(C_m,delta_e);%   % = Elevator Control Power %
DeltaC_L = (S_t/S)*heta*diff(C_L_t,delta_e)*delta_e;
% diff(C_L_t,delta_e) = The Elevator Effectiveness %
C_m_delta_e = (S_t/S)*heta*diff(C_L_t,delta_e);
DeltaC_m = -V_H*heta*diff(C_L_t,delta_e)*delta_e;
delta_trim = -((C_m_0*C_L_alpha)+(C_m_alpha*C_L_trim)/(C_m_delta_e*C_L_alpha)-(C_m_alpha*C_L_alpha));

% Stick-Free Neutral Point %

x_NP_tonos = (x_ac/cbar)-(C_m_alpha_f/C_L_alpha_w)+heta*V_H*(C_L_alpha_t_tonosStoC/C_L_alpha_w)*(1-epsilon_alpha);


