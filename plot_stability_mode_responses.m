function plot_stability_mode_responses(out, plotFolder)
%PLOT_STABILITY_MODE_RESPONSES
% Create and save stability-mode response plots.
%
% Current implementation:
%   1) Longitudinal phugoid mode
%   2) Longitudinal short-period mode
%   3) Lateral roll mode, when lateral output is available
%   4) Lateral spiral mode, when lateral output is available
%   5) Lateral Dutch-roll mode, when lateral output is available
%
% Active default:
%   Each figure contains one panel:
%   normalized scalar modal-coordinate response, y(t)/max|y(t)|.
%
% Optional disabled panel:
%   The physically meaningful state perturbation panel is preserved inside
%   local_plot_two_panel_mode and can be re-enabled by setting
%   showPhysicalStatePanel = true.
%
% The old bottom-panel variables are still passed into the helper function.
%
% Notes:
%   - The responses are normalized; they are not dimensional time histories.
%   - A dimensional response requires a specific initial condition or control input.
%   - The time axis is selected automatically from the modal eigenvalue.
%
% Usage:
%   plot_stability_mode_responses(out)
%   plot_stability_mode_responses(out, plotFolder)
%
% If out is the combined runner output, this function uses both:
%   out.longitudinal
%   out.lateral_directional
%
% If out is a longitudinal-only output, this function creates only the
% longitudinal plots.

if nargin < 1 || ~isstruct(out)
    error('plot_stability_mode_responses:BadInput', ...
        'Input must be a longitudinal or combined output struct.');
end

if nargin < 2 || isempty(plotFolder)
    plotFolder = fullfile(pwd, 'Mode_Response_Plots');
end

if ~exist(plotFolder, 'dir')
    mkdir(plotFolder);
end

savedFiles = {};

% -------------------------------------------------------------------------
% Longitudinal plots
% -------------------------------------------------------------------------
[longOut, hasLong] = local_get_longitudinal_output(out);

if hasLong
    savedFiles = [savedFiles; local_plot_longitudinal_modes(longOut, plotFolder)];
else
    warning('plot_stability_mode_responses:NoLongitudinalOutput', ...
        'No longitudinal output was found. Longitudinal plots were skipped.');
end

% -------------------------------------------------------------------------
% Lateral/directional plots
% -------------------------------------------------------------------------
[latOut, hasLat] = local_get_lateral_output(out);

if hasLat
    savedFiles = [savedFiles; local_plot_lateral_modes(latOut, plotFolder)];
else
    fprintf('\nNo lateral/directional output was found. Lateral plots were skipped.\n');
end

fprintf('\nMode-response plots saved in:\n  %s\n', plotFolder);
fprintf('Saved files:\n');

for k = 1:numel(savedFiles)
    fprintf('  %s\n', savedFiles{k});
end

end

function savedFiles = local_plot_longitudinal_modes(longOut, plotFolder)
savedFiles = {};

if ~isfield(longOut,'A') || isempty(longOut.A) || ~isnumeric(longOut.A) || ~isequal(size(longOut.A), [4 4])
    warning('plot_stability_mode_responses:MissingLongitudinalA', ...
        'The longitudinal output does not contain a 4-by-4 state matrix A. Longitudinal plots skipped.');
    return;
end

A_long = longOut.A;

% Longitudinal state order in the current core:
%   x = [Delta_u; Delta_w; Delta_q; Delta_theta]

% -------------------------------------------------------------------------
% Longitudinal exact eigenpairs
% -------------------------------------------------------------------------
[V_long, D_long] = eig(A_long);
eig_long = diag(D_long);

posImagIdx = find(imag(eig_long) > 1.0e-8);

if isempty(posImagIdx)
    warning('plot_stability_mode_responses:NoLongitudinalOscillatoryModes', ...
        'No positive-imaginary longitudinal oscillatory modes were found.');
    return;
end

% Sort oscillatory modes by frequency, fastest first.
[~, freqOrder] = sort(abs(imag(eig_long(posImagIdx))), 'descend');
posImagIdx = posImagIdx(freqOrder);

% In the classical two-pair longitudinal case:
%   fast pair = short-period
%   slow pair = phugoid
idxShortExact = posImagIdx(1);
idxPhugoidExact = posImagIdx(end);

lambdaShortExact = eig_long(idxShortExact);
vecShortExact = V_long(:,idxShortExact);

lambdaPhugoidExact = eig_long(idxPhugoidExact);
vecPhugoidExact = V_long(:,idxPhugoidExact);

% -------------------------------------------------------------------------
% Longitudinal approximate / reduced-order modes
% -------------------------------------------------------------------------
[lambdaShortApprox, vecShortApprox] = local_short_period_approx_eigenpair(longOut);
[lambdaPhugoidApprox, vecPhugoidApprox] = local_phugoid_reduced_order_eigenpair(A_long);

% -------------------------------------------------------------------------
% Create plots
% -------------------------------------------------------------------------
saveFile = 'longitudinal_phugoid_response.png';
local_plot_two_panel_mode( ...
    lambdaPhugoidExact, vecPhugoidExact, 4, ...
    lambdaPhugoidApprox, vecPhugoidApprox, 2, ...
    'Longitudinal Phugoid Mode', ...
    'Phugoid Modal Response: Exact vs Reduced-Order Approximation', ...
    'Normalized phugoid modal response, y(t)/max|y(t)|', ...
    'Phugoid Pitch-Angle Response: Exact vs Reduced-Order Approximation', ...
    'Normalized pitch angle perturbation, \Delta\theta/max|\Delta\theta|', ...
    fullfile(plotFolder, saveFile));
savedFiles{end+1,1} = saveFile;

saveFile = 'longitudinal_short_period_response.png';
local_plot_two_panel_mode( ...
    lambdaShortExact, vecShortExact, 2, ...
    lambdaShortApprox, vecShortApprox, 1, ...
    'Longitudinal Short-Period Mode', ...
    'Short-Period Modal Response: Exact vs Approximation', ...
    'Normalized short-period modal response, y(t)/max|y(t)|', ...
    'Short-Period Angle-of-Attack Response: Exact vs Approximation', ...
    'Normalized angle-of-attack perturbation, \Delta\alpha/max|\Delta\alpha|', ...
    fullfile(plotFolder, saveFile));
savedFiles{end+1,1} = saveFile;

end

function savedFiles = local_plot_lateral_modes(latOut, plotFolder)
savedFiles = {};

if ~isfield(latOut,'state_space') || ~isfield(latOut.state_space,'A_lat') ...
        || isempty(latOut.state_space.A_lat) || ~isnumeric(latOut.state_space.A_lat) ...
        || ~isequal(size(latOut.state_space.A_lat), [4 4])
    warning('plot_stability_mode_responses:MissingLateralA', ...
        'The lateral output does not contain a 4-by-4 state matrix A_lat. Lateral plots skipped.');
    return;
end

A_lat = latOut.state_space.A_lat;

% Lateral state order in the current core:
%   x = [Delta_beta; Delta_p; Delta_r; Delta_phi]

[V_lat, D_lat] = eig(A_lat);
eig_lat = diag(D_lat);

realIdx = find(abs(imag(eig_lat)) <= 1.0e-8);
complexIdx = find(imag(eig_lat) > 1.0e-8);

if numel(realIdx) >= 1
    [~, localRollIdx] = max(abs(real(eig_lat(realIdx))));
    idxRollExact = realIdx(localRollIdx);

    [~, localSpiralIdx] = min(abs(real(eig_lat(realIdx))));
    idxSpiralExact = realIdx(localSpiralIdx);
else
    warning('plot_stability_mode_responses:NoLateralRealModes', ...
        'No real lateral modes were found. Roll and spiral plots skipped.');
    idxRollExact = [];
    idxSpiralExact = [];
end

if ~isempty(complexIdx)
    [~, localDutchIdx] = max(abs(imag(eig_lat(complexIdx))));
    idxDutchExact = complexIdx(localDutchIdx);
else
    warning('plot_stability_mode_responses:NoDutchRollMode', ...
        'No positive-imaginary Dutch-roll mode was found. Dutch-roll plot skipped.');
    idxDutchExact = [];
end

% -------------------------------------------------------------------------
% Roll mode
% -------------------------------------------------------------------------
if ~isempty(idxRollExact) && isfield(latOut,'approx') && isfield(latOut.approx,'roll') ...
        && isfield(latOut.approx.roll,'lambda') && isfinite(latOut.approx.roll.lambda)

    lambdaRollExact = eig_lat(idxRollExact);
    vecRollExact = V_lat(:,idxRollExact);

    lambdaRollApprox = latOut.approx.roll.lambda;
    vecRollApprox = 1;

    saveFile = 'lateral_roll_mode_response.png';
    local_plot_two_panel_mode( ...
        lambdaRollExact, vecRollExact, 2, ...
        lambdaRollApprox, vecRollApprox, 1, ...
        'Lateral Roll Mode', ...
        'Roll Modal Response: Exact vs Approximation', ...
        'Normalized roll modal response, y(t)/max|y(t)|', ...
        'Roll-Rate Response: Exact vs Approximation', ...
        'Normalized roll-rate perturbation, \Deltap/max|\Deltap|', ...
        fullfile(plotFolder, saveFile));
    savedFiles{end+1,1} = saveFile;
else
    warning('plot_stability_mode_responses:SkippingRollMode', ...
        'Roll-mode plot skipped because the exact or approximate roll root was unavailable.');
end

% -------------------------------------------------------------------------
% Spiral mode
% -------------------------------------------------------------------------
if ~isempty(idxSpiralExact) && isfield(latOut,'approx') && isfield(latOut.approx,'spiral') ...
        && isfield(latOut.approx.spiral,'lambda') && isfinite(latOut.approx.spiral.lambda)

    lambdaSpiralExact = eig_lat(idxSpiralExact);
    vecSpiralExact = V_lat(:,idxSpiralExact);

    lambdaSpiralApprox = latOut.approx.spiral.lambda;
    vecSpiralApprox = 1;

    saveFile = 'lateral_spiral_mode_response.png';
    local_plot_two_panel_mode( ...
        lambdaSpiralExact, vecSpiralExact, 4, ...
        lambdaSpiralApprox, vecSpiralApprox, 1, ...
        'Lateral Spiral Mode', ...
        'Spiral Modal Response: Exact vs Approximation', ...
        'Normalized spiral modal response, y(t)/max|y(t)|', ...
        'Spiral Bank-Angle Response: Exact vs Approximation', ...
        'Normalized bank-angle perturbation, \Delta\phi/max|\Delta\phi|', ...
        fullfile(plotFolder, saveFile));
    savedFiles{end+1,1} = saveFile;
else
    warning('plot_stability_mode_responses:SkippingSpiralMode', ...
        'Spiral-mode plot skipped because the exact or approximate spiral root was unavailable.');
end

% -------------------------------------------------------------------------
% Dutch-roll mode
% -------------------------------------------------------------------------
if ~isempty(idxDutchExact) && isfield(latOut,'approx') && isfield(latOut.approx,'dutch') ...
        && isfield(latOut.approx.dutch,'eigenvalues') && any(isfinite(latOut.approx.dutch.eigenvalues(:)))

    lambdaDutchExact = eig_lat(idxDutchExact);
    vecDutchExact = V_lat(:,idxDutchExact);

    [lambdaDutchApprox, vecDutchApprox] = local_dutch_approx_eigenpair(latOut);

    saveFile = 'lateral_dutch_roll_response.png';
    local_plot_two_panel_mode( ...
        lambdaDutchExact, vecDutchExact, 1, ...
        lambdaDutchApprox, vecDutchApprox, 1, ...
        'Lateral Dutch-Roll Mode', ...
        'Dutch-Roll Modal Response: Exact vs Approximation', ...
        'Normalized Dutch-roll modal response, y(t)/max|y(t)|', ...
        'Dutch-Roll Sideslip Response: Exact vs Approximation', ...
        'Normalized sideslip perturbation, \Delta\beta/max|\Delta\beta|', ...
        fullfile(plotFolder, saveFile));
    savedFiles{end+1,1} = saveFile;
else
    warning('plot_stability_mode_responses:SkippingDutchRollMode', ...
        'Dutch-roll plot skipped because the exact or approximate Dutch-roll root was unavailable.');
end

end

function [longOut, hasLong] = local_get_longitudinal_output(out)
hasLong = false;
longOut = struct();

if isfield(out, 'longitudinal') && isstruct(out.longitudinal)
    longOut = out.longitudinal;
    hasLong = true;
elseif isfield(out, 'A') && isnumeric(out.A)
    longOut = out;
    hasLong = true;
end
end

function [latOut, hasLat] = local_get_lateral_output(out)
hasLat = false;
latOut = struct();

if isfield(out, 'lateral_directional') && isstruct(out.lateral_directional)
    latOut = out.lateral_directional;
    hasLat = true;
elseif isfield(out, 'state_space') && isfield(out.state_space, 'A_lat') ...
        && isnumeric(out.state_space.A_lat)
    latOut = out;
    hasLat = true;
end
end

function [lambda, vec] = local_short_period_approx_eigenpair(longOut)
% Get the short-period approximation from out.approx.short_period.
%
% Approximate short-period state for plotting:
%   x_sp = [Delta_alpha]
%
% Since Delta_alpha ~= Delta_w/u0, and the plot is normalized, the shape is
% represented by the one-state modal component.

lambdaCandidates = [];

if isfield(longOut,'approx') && isfield(longOut.approx,'short_period') ...
        && isfield(longOut.approx.short_period,'eigenvalues')
    lambdaCandidates = longOut.approx.short_period.eigenvalues;
elseif isfield(longOut,'lambda_roots')
    lambdaCandidates = longOut.lambda_roots;
end

if isempty(lambdaCandidates) || all(~isfinite(lambdaCandidates))
    error('plot_stability_mode_responses:MissingShortPeriodApprox', ...
        'Could not find short-period approximate eigenvalues in the longitudinal output.');
end

lambdaCandidates = lambdaCandidates(:);

complexIdx = find(imag(lambdaCandidates) > 1.0e-8);

if ~isempty(complexIdx)
    [~, localIdx] = max(abs(imag(lambdaCandidates(complexIdx))));
    idx = complexIdx(localIdx);
else
    [~, idx] = max(abs(real(lambdaCandidates)));
end

lambda = lambdaCandidates(idx);
vec = 1;
end

function [lambda, vec] = local_phugoid_reduced_order_eigenpair(A)
% Reduced-order phugoid approximation from the existing full A matrix.
%
% State order in the current longitudinal core:
%   x = [Delta_u; Delta_w; Delta_q; Delta_theta]
%
% Slow states:
%   [Delta_u; Delta_theta]
%
% Fast states eliminated quasi-steadily:
%   [Delta_w; Delta_q]
%
% A_reduced = A_ss - A_sf*(A_ff\A_fs)

slowIdx = [1 4];
fastIdx = [2 3];

A_ss = A(slowIdx, slowIdx);
A_sf = A(slowIdx, fastIdx);
A_fs = A(fastIdx, slowIdx);
A_ff = A(fastIdx, fastIdx);

if rcond(A_ff) < 1.0e-12
    error('plot_stability_mode_responses:SingularFastBlock', ...
        'The fast-state block A_ff is nearly singular; reduced-order phugoid approximation cannot be formed safely.');
end

A_reduced = A_ss - A_sf * (A_ff \ A_fs);

[V, D] = eig(A_reduced);
eigReduced = diag(D);

complexIdx = find(imag(eigReduced) > 1.0e-8);

if ~isempty(complexIdx)
    [~, localIdx] = min(abs(imag(eigReduced(complexIdx))));
    idx = complexIdx(localIdx);
else
    [~, idx] = min(abs(real(eigReduced)));
end

lambda = eigReduced(idx);
vec = V(:,idx);
end

function [lambda, vec] = local_dutch_approx_eigenpair(latOut)
lambdaCandidates = latOut.approx.dutch.eigenvalues(:);
lambdaCandidates = lambdaCandidates(isfinite(lambdaCandidates));

if isempty(lambdaCandidates)
    error('plot_stability_mode_responses:MissingDutchApprox', ...
        'Could not find Dutch-roll approximate eigenvalues.');
end

complexIdx = find(imag(lambdaCandidates) > 1.0e-8);

if ~isempty(complexIdx)
    [~, localIdx] = max(abs(imag(lambdaCandidates(complexIdx))));
    idx = complexIdx(localIdx);
else
    [~, idx] = max(abs(real(lambdaCandidates)));
end

lambda = lambdaCandidates(idx);
vec = 1;
end

function local_plot_two_panel_mode( ...
    lambdaExact, vecExact, exactComponentIndex, ...
    lambdaApprox, vecApprox, approxComponentIndex, ...
    figureName, ...
    topTitle, topYLabel, ...
    bottomTitle, bottomYLabel, ...
    savePath)

% Set local_show_physical_state_panel() to true to restore the old lower panel.
showPhysicalStatePanel = local_show_physical_state_panel();

tFinal = local_auto_time_final([lambdaExact, lambdaApprox]);
t = linspace(0, tFinal, 2000);

yExact = local_modal_coordinate_response(lambdaExact, t);
yApprox = local_modal_coordinate_response(lambdaApprox, t);

if showPhysicalStatePanel
    stateExact = local_normalized_state_component_response(lambdaExact, vecExact, exactComponentIndex, t);
    stateApprox = local_normalized_state_component_response(lambdaApprox, vecApprox, approxComponentIndex, t);

    fig = figure('Name', figureName, 'Color','w', ...
        'Units','pixels', 'Position',[100 100 1400 850]);

    tl = tiledlayout(fig, 2, 1, ...
        'TileSpacing','compact', ...
        'Padding','compact');
else
    fig = figure('Name', figureName, 'Color','w', ...
        'Units','pixels', 'Position',[100 100 1400 520]);

    tl = tiledlayout(fig, 1, 1, ...
        'TileSpacing','compact', ...
        'Padding','compact');
end

ax1 = nexttile(tl);
plot(ax1, t, yExact, 'b-', 'LineWidth', 2.0, 'DisplayName','Exact full order');
hold(ax1, 'on');
plot(ax1, t, yApprox, 'r--', 'LineWidth', 1.8, 'DisplayName','Approximation');
grid(ax1, 'on');
yline(ax1, 0, 'k:', 'HandleVisibility','off');

xlabel(ax1, 't (seconds)');
ylabel(ax1, 'Normalized response');
title(ax1, topTitle);
subtitle(ax1, topYLabel);
legend(ax1, 'show', 'Location','best');

if showPhysicalStatePanel
    ax2 = nexttile(tl);
    plot(ax2, t, stateExact, 'b-', 'LineWidth', 2.0, 'DisplayName','Exact full order');
    hold(ax2, 'on');
    plot(ax2, t, stateApprox, 'r--', 'LineWidth', 1.8, 'DisplayName','Approximation');
    grid(ax2, 'on');
    yline(ax2, 0, 'k:', 'HandleVisibility','off');

    xlabel(ax2, 't (seconds)');
    ylabel(ax2, 'Normalized response');
    title(ax2, bottomTitle);
    subtitle(ax2, bottomYLabel);
    legend(ax2, 'show', 'Location','best');
end

% Save PNG.
try
    exportgraphics(fig, savePath, 'Resolution', 300);
catch
    saveas(fig, savePath);
end

fprintf('\n---- %s ----\n', figureName);
fprintf('Exact root        : %.6e %+.6ei 1/s\n', real(lambdaExact), imag(lambdaExact));
fprintf('Approximate root  : %.6e %+.6ei 1/s\n', real(lambdaApprox), imag(lambdaApprox));
fprintf('Automatic tFinal  : %.3f s\n', tFinal);
fprintf('Saved plot        : %s\n', savePath);

end

function tf = local_show_physical_state_panel()
% RETURN TRUE TO RESTORE THE OLD LOWER PHYSICAL-STATE PERTURBATION PANEL.
tf = false;
end

function tFinal = local_auto_time_final(lambdaList)
% Automatically choose a time axis based on convergence/divergence.
%
% Stable modes:
%   show until the envelope decays to about 5% of the initial value.
%
% Unstable modes:
%   show until the envelope grows to about 5 times the initial value.
%
% Oscillatory modes:
%   always show at least 4 cycles when practical.
%
% Safety limits prevent unreadably tiny or enormous plots.

decayThreshold = 0.05;
growthFactor = 5.0;
minCycles = 4;

minTime = 0.5;
maxTime = 300.0;

candidateTimes = [];

for k = 1:numel(lambdaList)
    lambda = lambdaList(k);

    if ~isfinite(lambda)
        continue;
    end

    eta = real(lambda);
    omega = abs(imag(lambda));

    if eta < -1.0e-10
        tEnv = -log(decayThreshold) / abs(eta);
    elseif eta > 1.0e-10
        tEnv = log(growthFactor) / eta;
    else
        tEnv = NaN;
    end

    if omega > 1.0e-10
        T = 2*pi / omega;
        tCycle = minCycles * T;
    else
        tCycle = NaN;
    end

    if isfinite(tEnv) && isfinite(tCycle)
        candidateTimes(end+1) = max(tEnv, tCycle); %#ok<AGROW>
    elseif isfinite(tEnv)
        candidateTimes(end+1) = tEnv; %#ok<AGROW>
    elseif isfinite(tCycle)
        candidateTimes(end+1) = tCycle; %#ok<AGROW>
    end
end

if isempty(candidateTimes)
    tFinal = 20;
else
    tFinal = max(candidateTimes);
end

tFinal = max(minTime, min(maxTime, tFinal));

% Round upward to a readable axis length.
if tFinal <= 5
    tFinal = ceil(tFinal*10)/10;
elseif tFinal <= 30
    tFinal = ceil(tFinal);
elseif tFinal <= 120
    tFinal = ceil(tFinal/5)*5;
else
    tFinal = ceil(tFinal/10)*10;
end
end

function y = local_modal_coordinate_response(lambda, t)
% Return a normalized scalar modal-coordinate response.
% Complex root: decaying/growing sinusoid starting from zero.
% Real root   : decaying/growing exponential normalized to y(0)=1.

if abs(imag(lambda)) > 1.0e-10
    y = exp(real(lambda).*t) .* sin(abs(imag(lambda)).*t);
else
    y = exp(real(lambda).*t);
end

y = local_normalize_response(y);
end

function y = local_normalized_state_component_response(lambda, vec, componentIndex, t)
% Return a normalized response of one state component from the mode eigenvector.
%
% For complex modes, the arbitrary eigenvector phase is chosen so that the
% selected state component starts at zero with positive initial slope.

component = vec(componentIndex);

if abs(component) < 1.0e-12
    error('plot_stability_mode_responses:ZeroComponent', ...
        'The selected eigenvector component is too close to zero to normalize safely.');
end

if abs(imag(lambda)) > 1.0e-10
    phaseScale = -1i / component;
else
    phaseScale = 1 / component;
end

componentResponse = component * phaseScale .* exp(lambda .* t);
y = real(componentResponse);

y = local_normalize_response(y);
end

function y = local_normalize_response(y)
maxAbsY = max(abs(y));

if isfinite(maxAbsY) && maxAbsY > 0
    y = y ./ maxAbsY;
end
end
