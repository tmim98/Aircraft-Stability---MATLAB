function [k_Rl, dbg] = kRl_from_fig230(R_lf)
%KRl_FROM_FIG230  Approximate k_Rl from Nelson Fig. 2.30.
%
%   [k_Rl, dbg] = kRl_from_fig230(R_lf)
%
% Input
%   R_lf : fuselage Reynolds number, defined in the figure as V*l_f/nu
%
% Output
%   k_Rl : approximate empirical factor from Fig. 2.30
%   dbg  : struct with intermediate values
%
% Notes
% - This is a first-pass digitization from a user-provided scan.
% - The vertical axis in Fig. 2.30 is logarithmic: R_lf x 10^-6.
% - The mapping is implemented as a straight line in log10(R_lf x 10^-6).
%
% Valid chart range from the figure:
%   1e6 <= R_lf <= 1e9 approximately, with k_Rl in [1.0, 2.2].

    arguments
        R_lf (1,1) double {mustBePositive}
    end

    Rm = R_lf * 1e-6;   % plotted quantity on the vertical axis

    % First-pass fit from digitized chart geometry:
    % k_Rl ~= a + b * log10(Rm)
    a = 0.9730;
    b = 0.2063;

    if Rm < 1 || Rm > 1000
        warning(['R_lf is outside the nominal Fig. 2.30 range. ', ...
                 'Result is an extrapolation of the digitized fit.']);
    end

    k_Rl = a + b * log10(Rm);

    % Soft clipping to the chart bounds
    k_Rl = max(1.0, min(2.2, k_Rl));

    dbg = struct();
    dbg.R_lf = R_lf;
    dbg.Rlf_x1e_minus6 = Rm;
    dbg.log10_Rlf_x1e_minus6 = log10(Rm);
    dbg.fit_a = a;
    dbg.fit_b = b;
end
