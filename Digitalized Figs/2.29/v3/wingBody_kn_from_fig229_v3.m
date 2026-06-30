function [kn, debug] = wingBody_kn_from_fig229_v3(xm_lf, lf2_Sfs, sqrt_h1_h2, h_wf)
%WINGBODY_KN_FROM_FIG229_V3 Third-pass digitization of Nelson Fig. 2.29.
%
%   [kn, debug] = wingBody_kn_from_fig229_v3(xm_lf, lf2_Sfs, sqrt_h1_h2, h_wf)
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
% Method summary
%   This version uses:
%     1) grid-calibrated coordinates for each crop,
%     2) line-family fits from the cropped images,
%     3) interpolation only between neighboring labeled lines,
%     4) a mild cross-block y-registration calibration informed by the
%        shared grid and by the user's manual spot-checks.
%
% Notes
%   - This is still an engineering approximation from screenshot crops.
%   - It is more trustworthy than the earlier passes near the pivot regions,
%     but it should still be treated as an approximate chart reader.
%   - No synthetic "in-between" points are stored in the CSV; interpolation
%     is performed here in MATLAB, which is the safer design.

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

    % -----------------------------
    % Upper-left block calibration
    % -----------------------------
    ul_param = [2.5 3 4 5 6 7 8 10 14 20];
    ul_x_left = 13.0;     % x_m/l_f = 0.1
    ul_x_right = 384.0;   % x_m/l_f = 0.8

    % Re-estimated from the cropped upper-left panel using line clustering.
    ul_y_left  = [177.971340 198.996169 227.327067 251.566522 277.310884 ...
                  297.176473 311.960573 323.768457 348.129466 365.246295];
    ul_y_right = [ 41.656610  70.503208 104.407804 132.572839 158.037950 ...
                  177.572567 191.879097 203.664174 228.269485 242.643603];

    x_ul = ul_x_left + (xm_lf - 0.1) / (0.8 - 0.1) * (ul_x_right - ul_x_left);

    yL = interp1(ul_param, ul_y_left,  lf2_Sfs, 'linear');
    yR = interp1(ul_param, ul_y_right, lf2_Sfs, 'linear');
    y_ul = yL + (x_ul - ul_x_left) / (ul_x_right - ul_x_left) * (yR - yL);

    % -----------------------------------------------
    % Shared UL -> UR y-registration (grid-calibrated)
    % -----------------------------------------------
    % A strict pixel-offset mapping produced systematic local bias.  The
    % following affine mapping is based on shared-grid registration and then
    % lightly calibrated against hand-check points supplied by the user.
    y_ur = 13.596622 + 0.937534 * y_ul;

    % -----------------------------
    % Upper-right block calibration
    % -----------------------------
    ur_param = [0.8 1.0 1.2 1.4 1.6];
    ur_x0 = 20.0;         % common pivot x in cropped UR block
    ur_y0 = 343.0;        % common pivot y in cropped UR block
    ur_pitch_x = (337.0 - 20.0) / 6.0;

    % Re-estimated from the cropped upper-right panel.
    ur_m = [-1.282268 -1.056315 -0.869715 -0.754873 -0.651388];

    m_ur = interp1(ur_param, ur_m, sqrt_h1_h2, 'linear');
    x_ur = ur_x0 + (y_ur - ur_y0) / m_ur;

    % -----------------------------
    % Lower-right / k_n calibration
    % -----------------------------
    lr_param = [0.5 0.6 0.8 1.0 2.0];
    lr_x0 = 161.0;        % common pivot x in cropped lower-right / k_n block
    lr_y0 = 30.0;         % common pivot y in cropped lower-right / k_n block
    kn_x_pitch = (425.0 - 55.0) / 7.0;

    % Re-estimated from the cropped lower-right / k_n panel.
    lr_m = [0.555556 0.726564 0.965642 1.146960 1.279635];

    % Carry down the UR x-position into the lower-right block in normalized
    % grid-column coordinates instead of raw-pixel offsets.
    c = (x_ur - ur_x0) / ur_pitch_x;
    x_kn = lr_x0 + c * kn_x_pitch;

    m_lr = interp1(lr_param, lr_m, h_wf, 'linear');
    y_kn = lr_y0 + m_lr * (x_kn - lr_x0);

    % Read k_n from the vertical scale.  In the cropped k_n panel, y = 61 is
    % k_n = 0 and y = 400 is k_n = 0.006.
    kn = (y_kn - 61.0) / ((400.0 - 61.0) / 6.0) * 0.001;

    % Clip tiny excursions caused by scan thickness or interpolation.
    kn = max(0.0, min(0.006, kn));

    debug = struct();
    debug.x_ul = x_ul;
    debug.y_ul = y_ul;
    debug.y_ur = y_ur;
    debug.m_ur = m_ur;
    debug.x_ur = x_ur;
    debug.grid_column = c;
    debug.x_kn = x_kn;
    debug.m_lr = m_lr;
    debug.y_kn = y_kn;
end
