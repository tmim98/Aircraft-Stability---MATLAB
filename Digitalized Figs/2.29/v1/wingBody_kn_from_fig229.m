
function [kn, debug] = wingBody_kn_from_fig229(xm_lf, lf2_Sfs, sqrt_h1_h2, h_wf)
%WINGBODY_KN_FROM_FIG229 Approximate digitization of Nelson Fig. 2.29.
%
%   [kn, debug] = wingBody_kn_from_fig229(xm_lf, lf2_Sfs, sqrt_h1_h2, h_wf)
%
% Inputs
%   xm_lf       = x_m / l_f              valid range: [0.1, 0.8]
%   lf2_Sfs     = l_f^2 / S_fs           valid range: [2.5, 20]
%   sqrt_h1_h2  = sqrt(h1 / h2)          valid range: [0.8, 1.6]
%   h_wf        = h / w_f                valid range: [0.5, 2.0]
%
% Output
%   kn          = wing-body interference factor (approximate)
%   debug       = struct with intermediate nomogram coordinates
%
% Notes
%   This function is based on a manual/approximate digitization of the scan
%   supplied in chat, not the original printed plate. Treat it as a first-pass
%   engineering approximation and validate against additional hand readings.

    arguments
        xm_lf (1,1) double
        lf2_Sfs (1,1) double
        sqrt_h1_h2 (1,1) double
        h_wf (1,1) double
    end

    validateattributes(xm_lf, {'double'}, {'>=',0.1,'<=',0.8}, mfilename, 'xm_lf');
    validateattributes(lf2_Sfs, {'double'}, {'>=',2.5,'<=',20}, mfilename, 'lf2_Sfs');
    validateattributes(sqrt_h1_h2, {'double'}, {'>=',0.8,'<=',1.6}, mfilename, 'sqrt_h1_h2');
    validateattributes(h_wf, {'double'}, {'>=',0.5,'<=',2.0}, mfilename, 'h_wf');

    % ---- Digitized family definitions in image-pixel coordinates ----
    % Upper-left block: line family for l_f^2 / S_fs
    ul_param   = [2.5 3 4 5 6 7 8 10 14 20];
    ul_y_left  = [338.5 352.7 375.2 396.4 415.9 430.9 441.0 451.3 472.3 485.4];
    ul_y_right = [232.0 253.1 278.9 300.7 320.7 336.2 350.0 360.5 377.9 389.4];

    % Upper-right block: rays for sqrt(h1/h2)
    ur_param = [0.8 1.0 1.2 1.4 1.6];
    ur_m     = [-1.283 -1.073 -0.873 -0.754 -0.653];  % y = y0 + m*(x-x0)

    % Lower-right block: rays for h / w_f
    lr_param = [0.5 0.6 0.8 1.0 2.0];
    lr_m     = [0.555 0.731 0.967 1.146 1.280];       % y = y0 + m*(x-x0)

    % ---- Common chart geometry in image-pixel coordinates ----
    x_left0   = 147.0;  % x_m/l_f = 0.1
    x_left1   = 441.0;  % x_m/l_f = 0.8 / shared center line
    x0        = 441.0;  % centerline used by upper-right / lower-right rays
    y0_top    = 469.0;  % apex of upper-right rays
    y0_bottom = 534.0;  % apex of lower-right rays
    kn_top    = 534.0;  % k_n = 0
    kn_bottom = 828.0;  % k_n = 0.006

    % ---- Step 1: x_m/l_f to horizontal location in upper-left block ----
    x = x_left0 + (xm_lf - 0.1) / (0.8 - 0.1) * (x_left1 - x_left0);

    % ---- Step 2: interpolate the l_f^2/S_fs family and find the y-level ----
    yL = interp1(ul_param, ul_y_left,  lf2_Sfs, 'linear');
    yR = interp1(ul_param, ul_y_right, lf2_Sfs, 'linear');
    y_top = yL + (x - x_left0) / (x_left1 - x_left0) * (yR - yL);

    % ---- Step 3: cross the upper-right ray family to get the carry-down x ----
    m_ur = interp1(ur_param, ur_m, sqrt_h1_h2, 'linear');
    x_col = x0 + (y_top - y0_top) / m_ur;

    % ---- Step 4: project through the lower-right ray family ----
    m_lr = interp1(lr_param, lr_m, h_wf, 'linear');
    y_bottom = y0_bottom + m_lr * (x_col - x0);

    % ---- Step 5: read k_n from the center vertical scale ----
    kn = (y_bottom - kn_top) / (kn_bottom - kn_top) * 0.006;

    % Prevent small negative / overshoot values caused by scan-quality error.
    kn = max(0.0, min(0.006, kn));

    debug = struct();
    debug.x_px = x;
    debug.y_top_px = y_top;
    debug.x_col_px = x_col;
    debug.y_bottom_px = y_bottom;
    debug.m_ur = m_ur;
    debug.m_lr = m_lr;
end
