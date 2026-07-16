function plot_files = plot_parametric_results(param_out, output_folder, options)
% PLOT_PARAMETRIC_RESULTS Create PA-3 plots from run_parametric_sweep.m output.
%
%   plot_files = plot_parametric_results(param_out)
%   plot_files = plot_parametric_results(param_out, output_folder)
%   plot_files = plot_parametric_results(param_out, output_folder, options)
%
% Purpose
%   PA-3 plot layer for the parametric-analysis workflow. This function
%   creates summary plots from an already-computed parametric sweep. It does
%   not rerun any analysis and does not modify aircraft input files.
%
% Typical use after run_combined_AVS_analysis_FINAL.m and run_parametric_sweep.m
%   param_out = run_parametric_sweep(long_pAV, lat_pAV, 'u_0');
%   plot_parametric_results(param_out, 'PA3_u0_plots_NAVION');
%
% Plots generated for u_0 sweep
%   1. Stability envelope: max(real(lambda)) versus u_0.
%   2. CL0 and qbar versus u_0.
%   3. Longitudinal eigenvalue root-locus-style plot.
%   4. Lateral/directional eigenvalue root-locus-style plot.
%   5. Longitudinal A-matrix percent-change sensitivity.
%   6. Lateral/directional A-matrix percent-change sensitivity.
%
% Options
%   options.figure_visible     'off' by default
%   options.image_format       'png' by default
%   options.close_figures      true by default
%
% Output
%   plot_files : cell array with generated file paths.

if nargin < 3 || isempty(options)
    options = struct();
end

if nargin < 1 || ~isstruct(param_out)
    error('plot_parametric_results:InvalidInput', ...
        'Provide param_out returned by run_parametric_sweep.m.');
end

if nargin < 2 || isempty(output_folder)
    parameter_name = local_get_nested_text(param_out, {'sweep','parameter_name'}, 'parameter');
    output_folder = sprintf('parametric_%s_plots', local_sanitize_filename(parameter_name));
end

if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end

figure_visible = local_get_option(options, 'figure_visible', 'off');
image_format = local_get_option(options, 'image_format', 'png');
close_figures = local_get_option(options, 'close_figures', true);

plot_files = {};
summary = local_get_summary(param_out);
if isempty(summary) || height(summary) < 1
    error('plot_parametric_results:MissingSummary', ...
        'param_out.summary_table is missing or empty.');
end

parameter_name = local_get_nested_text(param_out, {'sweep','parameter_name'}, 'parameter');
file_prefix = local_sanitize_filename(parameter_name);

% 1. Stability envelope
fig = figure('Visible', figure_visible, 'Name', 'Parametric Stability Envelope');
hold on;
if ismember('Long_MaxRealEig', summary.Properties.VariableNames)
    plot(summary.u0_kt, summary.Long_MaxRealEig, '-o', 'DisplayName', 'Longitudinal');
end
if ismember('Lat_MaxRealEig', summary.Properties.VariableNames)
    plot(summary.u0_kt, summary.Lat_MaxRealEig, '-s', 'DisplayName', 'Lateral/directional');
end
yline(0, '--', 'DisplayName', 'Neutral stability boundary');
grid on;
xlabel('u_0 [kt]');
ylabel('max(real(\lambda)) [1/s]');
title('Parametric Stability Envelope for u_0 Sweep');
legend('Location', 'best');
plot_files{end+1,1} = local_save_figure(fig, output_folder, [file_prefix '_stability_envelope'], image_format, close_figures); %#ok<AGROW>

% 2. CL0 and qbar
fig = figure('Visible', figure_visible, 'Name', 'Parametric CL0 and qbar');
subplot(2,1,1);
hold on;
if ismember('Long_CL0', summary.Properties.VariableNames)
    plot(summary.u0_kt, summary.Long_CL0, '-o', 'DisplayName', 'Longitudinal CL0');
end
if ismember('Lat_CL0', summary.Properties.VariableNames)
    plot(summary.u0_kt, summary.Lat_CL0, '-s', 'DisplayName', 'Lateral CL0');
end
grid on;
xlabel('u_0 [kt]');
ylabel('CL0 [-]');
title('Trim-Consistent CL0 Scaling');
legend('Location', 'best');

subplot(2,1,2);
hold on;
if ismember('Long_qbar_psf', summary.Properties.VariableNames)
    plot(summary.u0_kt, summary.Long_qbar_psf, '-o', 'DisplayName', 'Longitudinal qbar');
end
if ismember('Lat_qbar_psf', summary.Properties.VariableNames)
    plot(summary.u0_kt, summary.Lat_qbar_psf, '-s', 'DisplayName', 'Lateral qbar');
end
grid on;
xlabel('u_0 [kt]');
ylabel('qbar [psf]');
title('Dynamic Pressure Scaling');
legend('Location', 'best');
plot_files{end+1,1} = local_save_figure(fig, output_folder, [file_prefix '_CL0_qbar'], image_format, close_figures); %#ok<AGROW>

% 3. Longitudinal eigenvalue root-locus-style plot
E_long = local_get_eigen_matrix(param_out, 'longitudinal');
if ~isempty(E_long)
    fig = local_eigenvalue_figure(E_long, summary, 'Longitudinal Eigenvalue Movement', figure_visible, 'longitudinal');
    plot_files{end+1,1} = local_save_figure(fig, output_folder, [file_prefix '_longitudinal_eigenvalues'], image_format, close_figures); %#ok<AGROW>
end

% 4. Lateral eigenvalue root-locus-style plot
E_lat = local_get_eigen_matrix(param_out, 'lateral_directional');
if ~isempty(E_lat)
    fig = local_eigenvalue_figure(E_lat, summary, 'Lateral/Directional Eigenvalue Movement', figure_visible, 'lateral_directional');
    plot_files{end+1,1} = local_save_figure(fig, output_folder, [file_prefix '_lateral_eigenvalues'], image_format, close_figures); %#ok<AGROW>
end

% 5. Longitudinal A matrix sensitivity
A_long = local_get_matrix(param_out, 'longitudinal', 'A');
if ~isempty(A_long)
    fig = local_matrix_sensitivity_figure(A_long, param_out, summary, 'Longitudinal A-Matrix Sensitivity', figure_visible);
    plot_files{end+1,1} = local_save_figure(fig, output_folder, [file_prefix '_A_long_sensitivity'], image_format, close_figures); %#ok<AGROW>
end

% 6. Lateral A matrix sensitivity
A_lat = local_get_matrix(param_out, 'lateral_directional', 'A');
if ~isempty(A_lat)
    fig = local_matrix_sensitivity_figure(A_lat, param_out, summary, 'Lateral/Directional A-Matrix Sensitivity', figure_visible);
    plot_files{end+1,1} = local_save_figure(fig, output_folder, [file_prefix '_A_lat_sensitivity'], image_format, close_figures); %#ok<AGROW>
end

end

function fig = local_eigenvalue_figure(E, summary, plot_title, figure_visible, branch_name)
fig = figure('Visible', figure_visible, 'Name', plot_title);
hold on;
grid on;

[nmodes, ~] = size(E);
baseline_idx = local_find_baseline_from_summary(summary);
plot_groups = local_build_eigen_plot_groups(E, baseline_idx, branch_name);

if isempty(plot_groups)
    for mode_idx = 1:nmodes
        vals = E(mode_idx, :);
        plot(real(vals), imag(vals), '-o', 'DisplayName', sprintf('eig %d', mode_idx));
    end
else
    for group_idx = 1:numel(plot_groups)
        modes = plot_groups(group_idx).modes;
        x_all = [];
        y_all = [];
        for k = 1:numel(modes)
            vals = E(modes(k), :);
            x_all = [x_all, real(vals), NaN]; %#ok<AGROW>
            y_all = [y_all, imag(vals), NaN]; %#ok<AGROW>
        end
        plot(x_all, y_all, '-o', 'DisplayName', plot_groups(group_idx).label);
    end
end

xline(0, '--', 'DisplayName', 'Neutral stability boundary');
yline(0, ':', 'DisplayName', 'Imaginary axis');

if ~isnan(baseline_idx)
    for mode_idx = 1:nmodes
        vals = E(mode_idx, baseline_idx);
        if mode_idx == 1
            plot(real(vals), imag(vals), 'p', 'MarkerSize', 10, 'DisplayName', 'Baseline point');
        else
            plot(real(vals), imag(vals), 'p', 'MarkerSize', 10, 'HandleVisibility', 'off');
        end
    end
end

xlabel('Real(\lambda) [1/s]');
ylabel('Imag(\lambda) [rad/s]');
title(plot_title);
legend('Location', 'best');
end

function fig = local_matrix_sensitivity_figure(M, param_out, summary, plot_title, figure_visible)
fig = figure('Visible', figure_visible, 'Name', plot_title, ...
    'Units', 'pixels', 'Position', [100 100 1300 760]);

baseline_idx = local_get_baseline_index(param_out);
if isnan(baseline_idx)
    baseline_idx = local_find_baseline_from_summary(summary);
end

[nrow, ncol, npoints] = size(M);
percent_change = NaN(nrow, ncol, npoints);
if ~isnan(baseline_idx)
    M0 = M(:, :, baseline_idx);
    for k = 1:npoints
        for i = 1:nrow
            for j = 1:ncol
                base_value = M0(i,j);
                if isfinite(base_value) && abs(base_value) > eps
                    percent_change(i,j,k) = 100.0 * (M(i,j,k) - base_value) / base_value;
                end
            end
        end
    end
end

max_abs_percent_change = NaN(nrow, ncol);
for i = 1:nrow
    for j = 1:ncol
        values = squeeze(abs(percent_change(i,j,:)));
        values = values(isfinite(values));
        if ~isempty(values)
            max_abs_percent_change(i,j) = max(values);
        end
    end
end

if all(isnan(max_abs_percent_change(:)))
    max_abs_percent_change = zeros(nrow, ncol);
end

imagesc(max_abs_percent_change);
ax = gca;
cb = colorbar(ax);
ylabel(cb, 'Max |% change| from baseline [%]');
axis equal tight;
xlabel('Matrix column / state variable');
ylabel('Matrix row / state equation');
title(sprintf('%s: max |%% change| from baseline', plot_title));
set(ax, 'XTick', 1:ncol, 'YTick', 1:nrow, 'TickLabelInterpreter', 'none');

[row_labels, column_labels] = local_matrix_axis_labels(plot_title, nrow, ncol);
if ~isempty(row_labels) && ~isempty(column_labels)
    set(ax, 'XTickLabel', column_labels, 'YTickLabel', row_labels);
end

% Reserve enough left margin for row tick labels and the y-axis label.
% Keep the colorbar close to the heatmap so horizontal space is not wasted.
set(ax, 'Units', 'normalized', 'Position', [0.30 0.17 0.50 0.68]);
set(cb, 'Units', 'normalized', 'Position', [0.815 0.17 0.025 0.68]);

for i = 1:nrow
    for j = 1:ncol
        value = max_abs_percent_change(i,j);
        if isfinite(value)
            label_text = sprintf('%.2g%%', value);
        else
            label_text = 'NaN';
        end
        text(j, i, label_text, 'HorizontalAlignment', 'center');
    end
end
end

function plot_groups = local_build_eigen_plot_groups(E, baseline_idx, branch_name)
plot_groups = struct('modes', {}, 'label', {});
[nmodes, ~] = size(E);

if isnan(baseline_idx) || baseline_idx < 1 || baseline_idx > size(E,2)
    return;
end

baseline_vals = E(:, baseline_idx);
complex_tol = 1.0e-8;
is_complex = abs(imag(baseline_vals)) > complex_tol;
used = false(nmodes, 1);
pairs = {};
real_modes = [];

for i = 1:nmodes
    if used(i)
        continue;
    end

    if is_complex(i)
        candidates = find(~used & (1:nmodes)' ~= i & is_complex);
        if isempty(candidates)
            pairs{end+1} = i; %#ok<AGROW>
            used(i) = true;
        else
            score = abs(real(baseline_vals(candidates)) - real(baseline_vals(i))) + ...
                    abs(imag(baseline_vals(candidates)) + imag(baseline_vals(i)));
            [~, local_idx] = min(score);
            j = candidates(local_idx);
            pairs{end+1} = sort([i j]); %#ok<AGROW>
            used([i j]) = true;
        end
    else
        real_modes(end+1) = i; %#ok<AGROW>
        used(i) = true;
    end
end

switch branch_name
    case 'longitudinal'
        if numel(pairs) >= 2
            pair_imag = zeros(numel(pairs), 1);
            for k = 1:numel(pairs)
                pair_imag(k) = mean(abs(imag(baseline_vals(pairs{k}))));
            end
            [~, order] = sort(pair_imag, 'descend');
            short_idx = order(1);
            phugoid_idx = order(end);

            plot_groups(end+1) = local_make_group(pairs{short_idx}, 'Short-period'); %#ok<AGROW>
            plot_groups(end+1) = local_make_group(pairs{phugoid_idx}, 'Phugoid'); %#ok<AGROW>

            for k = 1:numel(pairs)
                if k ~= short_idx && k ~= phugoid_idx
                    plot_groups(end+1) = local_make_group(pairs{k}, 'Longitudinal pair'); %#ok<AGROW>
                end
            end
        else
            for k = 1:numel(pairs)
                plot_groups(end+1) = local_make_group(pairs{k}, 'Longitudinal pair'); %#ok<AGROW>
            end
        end

        for k = 1:numel(real_modes)
            plot_groups(end+1) = local_make_group(real_modes(k), 'Longitudinal real mode'); %#ok<AGROW>
        end

    case 'lateral_directional'
        for k = 1:numel(pairs)
            plot_groups(end+1) = local_make_group(pairs{k}, 'Dutch roll'); %#ok<AGROW>
        end

        if ~isempty(real_modes)
            real_values = real(baseline_vals(real_modes));
            [~, order] = sort(real_values, 'ascend');
            roll_mode = real_modes(order(1));
            spiral_mode = real_modes(order(end));

            plot_groups(end+1) = local_make_group(roll_mode, 'Roll mode'); %#ok<AGROW>
            if spiral_mode ~= roll_mode
                plot_groups(end+1) = local_make_group(spiral_mode, 'Spiral mode'); %#ok<AGROW>
            end

            for k = 1:numel(real_modes)
                mode = real_modes(k);
                if mode ~= roll_mode && mode ~= spiral_mode
                    plot_groups(end+1) = local_make_group(mode, 'Lateral real mode'); %#ok<AGROW>
                end
            end
        end

    otherwise
        for k = 1:numel(pairs)
            plot_groups(end+1) = local_make_group(pairs{k}, 'Eigenvalue pair'); %#ok<AGROW>
        end
        for k = 1:numel(real_modes)
            plot_groups(end+1) = local_make_group(real_modes(k), 'Real eigenvalue'); %#ok<AGROW>
        end
end
end

function group = local_make_group(modes, mode_name)
modes = modes(:).';
if numel(modes) == 1
    label = sprintf('%s (eig %d)', mode_name, modes(1));
else
    label = sprintf('%s (eig %s)', mode_name, strjoin(arrayfun(@num2str, modes, 'UniformOutput', false), ','));
end
group = struct('modes', modes, 'label', label);
end

function [row_labels, column_labels] = local_matrix_axis_labels(plot_title, nrow, ncol)
row_labels = {};
column_labels = {};
if nrow ~= 4 || ncol ~= 4
    return;
end

if contains(plot_title, 'Longitudinal', 'IgnoreCase', true)
    % Active longitudinal A matrix uses x = [Delta_u; Delta_w; Delta_q; Delta_theta].
    column_labels = {'u','w','q','theta'};
    row_labels = {'u-dot (X/m)','w-dot (Z/m)','q-dot (M/Iyy)','theta-dot (kin.)'};
elseif contains(plot_title, 'Lateral', 'IgnoreCase', true)
    % Active lateral A matrix uses x = [Delta_beta; Delta_p; Delta_r; Delta_phi].
    column_labels = {'beta','p','r','phi'};
    row_labels = {'beta-dot (Y/m/u0)','p-dot (L/Ix)','r-dot (N/Iz)','phi-dot (kin.)'};
end
end

function file_path = local_save_figure(fig, output_folder, base_name, image_format, close_figures)
file_path = fullfile(output_folder, [base_name '.' image_format]);
try
    exportgraphics(fig, file_path, 'Resolution', 300);
catch ME
    try
        saveas(fig, file_path);
    catch ME2
        warning('plot_parametric_results:SaveFailed', ...
            'Could not save figure %s. exportgraphics error: %s. saveas error: %s', ...
            file_path, ME.message, ME2.message);
    end
end
if close_figures
    close(fig);
end
end

function summary = local_get_summary(param_out)
summary = table();
if isfield(param_out, 'summary_table') && istable(param_out.summary_table)
    summary = param_out.summary_table;
end
end

function E = local_get_eigen_matrix(param_out, branch_name)
E = [];
if ~isfield(param_out, 'eigenvalues') || ~isstruct(param_out.eigenvalues)
    return;
end
switch branch_name
    case 'longitudinal'
        if isfield(param_out.eigenvalues, 'longitudinal')
            E = param_out.eigenvalues.longitudinal;
        end
    case 'lateral_directional'
        if isfield(param_out.eigenvalues, 'lateral_directional')
            E = param_out.eigenvalues.lateral_directional;
        end
end
end

function M = local_get_matrix(param_out, branch_name, matrix_name)
M = [];
if ~isfield(param_out, 'matrices') || ~isstruct(param_out.matrices)
    return;
end
if ~isfield(param_out.matrices, branch_name) || ~isstruct(param_out.matrices.(branch_name))
    return;
end
if isfield(param_out.matrices.(branch_name), matrix_name)
    M = param_out.matrices.(branch_name).(matrix_name);
end
end

function idx = local_get_baseline_index(param_out)
idx = NaN;
if isfield(param_out, 'baseline') && isstruct(param_out.baseline) && ...
        isfield(param_out.baseline, 'index') && isnumeric(param_out.baseline.index) && isscalar(param_out.baseline.index)
    idx = param_out.baseline.index;
end
end

function idx = local_find_baseline_from_summary(summary)
idx = NaN;
if istable(summary) && ismember('SweepFactor', summary.Properties.VariableNames)
    [d, i] = min(abs(summary.SweepFactor - 1.0));
    if isfinite(d) && d <= 1.0e-10
        idx = i;
    end
end
end

function value = local_get_option(options, field_name, default_value)
if isstruct(options) && isfield(options, field_name) && ~isempty(options.(field_name))
    value = options.(field_name);
else
    value = default_value;
end
end

function text_value = local_get_nested_text(s, path_parts, default_value)
value = [];
current = s;
for k = 1:numel(path_parts)
    if isstruct(current) && isfield(current, path_parts{k})
        current = current.(path_parts{k});
    else
        text_value = default_value;
        return;
    end
end
value = current;
if ischar(value) || isstring(value)
    text_value = char(value);
else
    text_value = default_value;
end
end

function safe = local_sanitize_filename(text_in)
safe = regexprep(char(text_in), '[^A-Za-z0-9_\-]', '_');
if isempty(safe)
    safe = 'parameter';
end
end
