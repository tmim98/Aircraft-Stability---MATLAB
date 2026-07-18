function sweep = build_xcg_sweep_values(long_pAV, lat_pAV, options)
% BUILD_XCG_SWEEP_VALUES Build the accepted x_cg sweep vector for parametric analysis.
%
% sweep = build_xcg_sweep_values(long_pAV, lat_pAV)
% sweep = build_xcg_sweep_values(long_pAV, lat_pAV, options)
%
% Purpose
% Generates the requested x_cg sweep values using the nondimensional
% aircraft-independent coordinate:
%
%     cg_mac = x_cg / c_bar
%
% applies safety limits, and returns both requested and accepted sweep
% metadata. This helper does not run any stability analysis and does not
% modify the input structs.
%
% Default policy
%   Sweep range   : baseline cg_mac +/- 0.20 MAC
%   Safety limits : 0.05 <= cg_mac <= 0.60
%   Sweep points  : 9
%
% Output
%   sweep.parameter_name
%   sweep.units
%   sweep.baseline_cg_mac
%   sweep.baseline_x_cg_ft
%   sweep.c_bar_ft
%   sweep.requested_cg_mac
%   sweep.requested_x_cg_ft
%   sweep.accepted_cg_mac
%   sweep.accepted_x_cg_ft
%   sweep.safety_min_cg_mac
%   sweep.safety_max_cg_mac
%   sweep.was_clipped
%   sweep.warnings

if nargin < 3 || isempty(options)
    options = struct();
end

half_range_mac = local_get_option(options, 'xcg_half_range_mac', 0.20);
n_points = local_get_option(options, 'xcg_num_points', 9);
min_cg_mac = local_get_option(options, 'xcg_min_cg_mac', 0.05);
max_cg_mac = local_get_option(options, 'xcg_max_cg_mac', 0.60);
clip_to_limits = local_get_option(options, 'xcg_clip_to_limits', true);
tol = local_get_option(options, 'tolerance', 1.0e-10);

if ~isnumeric(half_range_mac) || ~isscalar(half_range_mac) || ~isfinite(half_range_mac) || half_range_mac <= 0
    error('build_xcg_sweep_values:InvalidHalfRange', ...
        'options.xcg_half_range_mac must be a positive finite scalar.');
end

if ~isnumeric(n_points) || ~isscalar(n_points) || ~isfinite(n_points) || n_points < 2
    error('build_xcg_sweep_values:InvalidPointCount', ...
        'options.xcg_num_points must be a finite scalar greater than or equal to 2.');
end

n_points = round(n_points);

if min_cg_mac >= max_cg_mac
    error('build_xcg_sweep_values:InvalidSafetyLimits', ...
        'The x_cg safety limits must satisfy min_cg_mac < max_cg_mac.');
end

warnings = {};

c_bar_ft = local_get_cbar_ft(long_pAV, lat_pAV);

if ~isfinite(c_bar_ft) || c_bar_ft <= 0
    error('build_xcg_sweep_values:MissingCbar', ...
        'Could not determine a positive c_bar in feet.');
end

baseline_x_cg_ft = local_get_xcg_ft(long_pAV, lat_pAV, c_bar_ft);

if ~isfinite(baseline_x_cg_ft)
    error('build_xcg_sweep_values:MissingXcg', ...
        'Could not determine baseline x_cg in feet.');
end

baseline_cg_mac = baseline_x_cg_ft / c_bar_ft;

requested_min_cg_mac = baseline_cg_mac - half_range_mac;
requested_max_cg_mac = baseline_cg_mac + half_range_mac;
requested_cg_mac = linspace(requested_min_cg_mac, requested_max_cg_mac, n_points);

accepted_cg_mac = requested_cg_mac;
was_clipped = false;

below_limit = requested_cg_mac < min_cg_mac - tol;
above_limit = requested_cg_mac > max_cg_mac + tol;

if any(below_limit) || any(above_limit)
    if clip_to_limits
        accepted_cg_mac = min(max(requested_cg_mac, min_cg_mac), max_cg_mac);
        was_clipped = true;
        warnings{end+1} = sprintf( ...
            ['Requested x_cg sweep exceeded the safety limits %.3f <= cg_mac <= %.3f. ', ...
             'Out-of-range values were clipped.'], ...
            min_cg_mac, max_cg_mac); %#ok<AGROW>
    else
        error('build_xcg_sweep_values:SafetyLimitExceeded', ...
            'Requested x_cg sweep exceeds the safety limits and clipping is disabled.');
    end
end

% Remove duplicated clipped values while preserving the sweep order.
[accepted_cg_mac, keep_idx] = unique(accepted_cg_mac, 'stable');

if numel(accepted_cg_mac) < numel(requested_cg_mac)
    warnings{end+1} = sprintf( ...
        'Duplicate clipped x_cg values were removed. Requested points: %d. Accepted points: %d.', ...
        numel(requested_cg_mac), numel(accepted_cg_mac)); %#ok<AGROW>
end

% Ensure the exact baseline CG is present.
if ~any(abs(accepted_cg_mac - baseline_cg_mac) <= max(tol, tol*abs(baseline_cg_mac)))
    accepted_cg_mac(end+1) = baseline_cg_mac;
    accepted_cg_mac = sort(accepted_cg_mac);
    warnings{end+1} = 'Baseline cg_mac was not in the requested sweep and was added automatically.'; %#ok<AGROW>
end

requested_x_cg_ft = requested_cg_mac .* c_bar_ft;
accepted_x_cg_ft = accepted_cg_mac .* c_bar_ft;

sweep = struct();
sweep.parameter_name = 'x_cg';
sweep.parameter_display_name = 'cg_mac';
sweep.units = 'MAC';
sweep.x_cg_units = 'ft';
sweep.baseline_cg_mac = baseline_cg_mac;
sweep.baseline_x_cg_ft = baseline_x_cg_ft;
sweep.c_bar_ft = c_bar_ft;
sweep.half_range_mac = half_range_mac;
sweep.requested_min_cg_mac = requested_min_cg_mac;
sweep.requested_max_cg_mac = requested_max_cg_mac;
sweep.requested_cg_mac = requested_cg_mac(:).';
sweep.requested_x_cg_ft = requested_x_cg_ft(:).';
sweep.accepted_cg_mac = accepted_cg_mac(:).';
sweep.accepted_x_cg_ft = accepted_x_cg_ft(:).';
sweep.safety_min_cg_mac = min_cg_mac;
sweep.safety_max_cg_mac = max_cg_mac;
sweep.was_clipped = was_clipped;
sweep.keep_idx_after_clipping = keep_idx(:).';
sweep.warnings = warnings;

end

function c_bar_ft = local_get_cbar_ft(long_pAV, lat_pAV)

c_bar_ft = local_first_finite([ ...
    local_get_numeric_field(long_pAV, 'c_bar_ft'), ...
    local_get_numeric_field(long_pAV, 'c_bar'), ...
    local_get_numeric_field(lat_pAV, 'c_bar_ft'), ...
    local_get_numeric_field(lat_pAV, 'c_bar')]);

end

function x_cg_ft = local_get_xcg_ft(long_pAV, lat_pAV, c_bar_ft)

x_cg_ft = local_first_finite([ ...
    local_get_numeric_field(long_pAV, 'x_cg_ft'), ...
    local_get_numeric_field(long_pAV, 'x_cg'), ...
    local_get_numeric_field(lat_pAV, 'x_cg_ft'), ...
    local_get_numeric_field(lat_pAV, 'x_cg')]);

if ~isfinite(x_cg_ft)
    cg_mac = local_first_finite([ ...
        local_get_numeric_field(long_pAV, 'cg_mac'), ...
        local_get_numeric_field(lat_pAV, 'cg_mac')]);

    if isfinite(cg_mac) && isfinite(c_bar_ft) && c_bar_ft > 0
        x_cg_ft = cg_mac * c_bar_ft;
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

function value = local_get_numeric_field(s, field_name)

value = NaN;

if isstruct(s) && isfield(s, field_name) && isnumeric(s.(field_name)) && isscalar(s.(field_name))
    value = s.(field_name);
end

end

function value = local_first_finite(values)

value = NaN;

for k = 1:numel(values)
    if isfinite(values(k))
        value = values(k);
        return;
    end
end

end
