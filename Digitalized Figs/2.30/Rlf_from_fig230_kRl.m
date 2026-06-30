function [R_lf, dbg] = Rlf_from_fig230_kRl(k_Rl)
%RLF_FROM_FIG230_KRL  Inverse of the first-pass Fig. 2.30 digitization.
%
%   [R_lf, dbg] = Rlf_from_fig230_kRl(k_Rl)
%
% Input
%   k_Rl : empirical factor from Fig. 2.30
%
% Output
%   R_lf : approximate Reynolds number V*l_f/nu
%   dbg  : struct with intermediate values
%
% Notes
% - Uses the same first-pass digitized fit as kRl_from_fig230.m
% - Vertical-axis quantity in the original chart is R_lf x 10^-6.

    arguments
        k_Rl (1,1) double
    end

    a = 0.9730;
    b = 0.2063;

    if k_Rl < 1.0 || k_Rl > 2.2
        warning(['k_Rl is outside the nominal Fig. 2.30 range. ', ...
                 'Result is an extrapolation of the digitized fit.']);
    end

    log10_Rm = (k_Rl - a) / b;
    Rm = 10.^log10_Rm;
    R_lf = Rm * 1e6;

    dbg = struct();
    dbg.k_Rl = k_Rl;
    dbg.Rlf_x1e_minus6 = Rm;
    dbg.log10_Rlf_x1e_minus6 = log10_Rm;
    dbg.fit_a = a;
    dbg.fit_b = b;
end
