
function [kn, debug] = wingBody_kn_from_fig229_v2(xm_lf, lf2_Sfs, sqrt_h1_h2, h_wf)
%WINGBODY_KN_FROM_FIG229_V2 Second-pass digitization of Nelson Fig. 2.29.
%
%   [kn, debug] = wingBody_kn_from_fig229_v2(xm_lf, lf2_Sfs, sqrt_h1_h2, h_wf)
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
%   This version was re-digitized from tighter crops of the three line-family
%   blocks. It treats Fig. 2.29 explicitly as a chained nomogram:
%     1) upper-left family: l_f^2 / S_fs
%     2) upper-right family: sqrt(h1/h2)
%     3) lower-right family: h / w_f
%   Compared with the first pass, the line families near the common pivots were
%   re-estimated more carefully, which improves behavior near the convergence
%   regions that are most sensitive to small coordinate errors.

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

    % ---------------------------------------------------------------------
    % Upper-left block (x_m/l_f versus l_f^2/S_fs)
    % Digitized from the cropped upper-left block.  The family lines were
    % estimated at two x-reference columns and then linearly interpolated.
    % ---------------------------------------------------------------------
    ul_param = [2.5 3 4 5 6 7 8 10 14 20];

    ul_x_refL = 13.0;   % approx. x_m/l_f = 0.1
    ul_x_refR = 384.0;  % approx. x_m/l_f = 0.8
    ul_y_refL = [179.1 201.6 225.3 253.5 278.8 297.9 311.2 323.6 346.2 364.7];
    ul_y_refR = [44.8 68.4 103.9 130.4 158.8 178.9 194.7 204.9 230.2 244.3];

    x_ul = ul_x_refL + (xm_lf - 0.1) / (0.8 - 0.1) * (ul_x_refR - ul_x_refL);

    yL = interp1(ul_param, ul_y_refL, lf2_Sfs, 'linear');
    yR = interp1(ul_param, ul_y_refR, lf2_Sfs, 'linear');
    y_ul = yL + (x_ul - ul_x_refL) / (ul_x_refR - ul_x_refL) * (yR - yL);

    % ---------------------------------------------------------------------
    % Upper-right block (sqrt(h1/h2))
    % Re-digitized from the cropped upper-right block.
    % ---------------------------------------------------------------------
    ur_param = [0.8 1.0 1.2 1.4 1.6];
    ur_x0 = 19.5;
    ur_y0 = 343.5;
    ur_m = [-1.285 -1.070 -0.880 -0.754 -0.655];   % y = y0 + m*(x-x0)

    % The upper-left and upper-right crops share the same vertical scale but
    % not the same pixel origin.  Empirically, the upper-right crop is about
    % 8 px higher than the upper-left crop.
    y_ur = y_ul - 8.0;

    m_ur = interp1(ur_param, ur_m, sqrt_h1_h2, 'linear');
    x_ur = ur_x0 + (y_ur - ur_y0) / m_ur;

    % ---------------------------------------------------------------------
    % Lower-right block (h/w_f and k_n scale)
    % Re-digitized from the cropped lower-right block with the k_n scale.
    % ---------------------------------------------------------------------
    lr_param = [0.5 0.6 0.8 1.0 2.0];
    lr_x0 = 161.5;
    lr_y0 = 61.0;
    lr_m  = [0.552 0.742 0.970 1.146 1.278];       % y = y0 + m*(x-x0)

    % The UR and LR blocks are horizontally offset in the supplied crops.
    x_lr = x_ur + (lr_x0 - ur_x0);

    m_lr = interp1(lr_param, lr_m, h_wf, 'linear');
    y_lr = lr_y0 + m_lr * (x_lr - lr_x0);

    % Read k_n from the central vertical scale.  The 0 and 0.006 marks are
    % approximately at y = 61 and y = 400 in the cropped image.
    kn = (y_lr - 61.0) / (400.0 - 61.0) * 0.006;

    % Scan thickness can cause tiny excursions near the bounds.
    kn = max(0.0, min(0.006, kn));

    debug = struct();
    debug.x_ul = x_ul;
    debug.y_ul = y_ul;
    debug.y_ur = y_ur;
    debug.x_ur = x_ur;
    debug.x_lr = x_lr;
    debug.y_lr = y_lr;
    debug.m_ur = m_ur;
    debug.m_lr = m_lr;
end
