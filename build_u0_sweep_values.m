function sweep = build_u0_sweep_values(long_pAV, lat_pAV, options)
% BUILD_U0_SWEEP_VALUES Build the accepted u_0 sweep vector for parametric analysis.
%
%   sweep = build_u0_sweep_values(long_pAV, lat_pAV)
%   sweep = build_u0_sweep_values(long_pAV, lat_pAV, options)
%
% Purpose
%   Generates the requested u_0 sweep values, applies the hard Mach cap, and
%   returns both requested and accepted sweep metadata. This helper does not run
%   any stability analysis and does not modify the input structs.
%
% Unit convention
%   The returned u_0 values are in knots, matching the current AVS input files:
%       longitudinal: pAV.u0_kt
%       lateral     : pAV.u0
%
% Default policy
%   Sweep factors : 0.80:0.05:1.20
%   Mach cap      : 0.90
%   Mach source   : options.speed_of_sound_kt, if provided;
%                   otherwise inferred from baseline u_0 and baseline M0.
%
% Output
%   sweep.parameter_name
%   sweep.baseline_u0_kt
%   sweep.requested_factors
%   sweep.requested_u0_kt
%   sweep.accepted_factors
%   sweep.accepted_u0_kt
%   sweep.accepted_mach
%   sweep.mach_cap
%   sweep.speed_of_sound_kt
%   sweep.was_clipped
%   sweep.warnings

if nargin < 3 || isempty(options)
    options = struct();
end

mach_cap = local_get_option(options, 'mach_cap', 0.90);
sweep_factors = local_get_option(options, 'sweep_factors', 0.80:0.05:1.20);
clip_to_mach_cap = local_get_option(options, 'clip_to_mach_cap', true);
tol = local_get_option(options, 'tolerance', 1.0e-10);

warnings = {};

baseline_u0_kt = local_first_finite([ ...
    local_get_u0_knots(long_pAV), ...
    local_get_u0_knots(lat_pAV)]);

if ~isfinite(baseline_u0_kt) || baseline_u0_kt <= 0
    error('build_u0_sweep_values:MissingU0', ...
        'Could not determine a positive baseline u_0 in knots.');
end

speed_of_sound_kt = local_get_option(options, 'speed_of_sound_kt', NaN);
if ~isfinite(speed_of_sound_kt)
    baseline_mach = local_first_finite([ ...
        local_get_numeric_field(long_pAV, 'M0'), ...
        local_get_numeric_field(lat_pAV, 'M0')]);

    if isfinite(baseline_mach) && baseline_mach > 0
        speed_of_sound_kt = baseline_u0_kt / baseline_mach;
    else
        error('build_u0_sweep_values:MissingMachSource', ...
            ['Could not determine speed of sound for the u_0 Mach cap. ', ...
             'Provide options.speed_of_sound_kt or a positive baseline M0.']);
    end
end

if ~isfinite(speed_of_sound_kt) || speed_of_sound_kt <= 0
    error('build_u0_sweep_values:InvalidSpeedOfSound', ...
        'The inferred or supplied speed of sound must be positive.');
end

requested_u0_kt = baseline_u0_kt .* sweep_factors(:).';
requested_mach = requested_u0_kt ./ speed_of_sound_kt;

u0_cap_kt = mach_cap * speed_of_sound_kt;
accepted_u0_kt = requested_u0_kt;
was_clipped = false;

if any(requested_mach > mach_cap + tol)
    if clip_to_mach_cap
        accepted_u0_kt = min(requested_u0_kt, u0_cap_kt);
        was_clipped = true;
        warnings{end+1} = sprintf( ...
            ['Requested u_0 sweep exceeded Mach %.3f. Values above %.6g knots ', ...
             'were clipped to the Mach cap.'], ...
            mach_cap, u0_cap_kt);
    else
        error('build_u0_sweep_values:MachCapExceeded', ...
            'Requested u_0 sweep exceeds Mach %.3f and clipping is disabled.', mach_cap);
    end
end

% Remove duplicated cap values while preserving the sweep order.
[accepted_u0_kt, keep_idx] = unique(accepted_u0_kt, 'stable');
accepted_factors = accepted_u0_kt ./ baseline_u0_kt;
accepted_mach = accepted_u0_kt ./ speed_of_sound_kt;

if numel(accepted_u0_kt) < numel(requested_u0_kt)
    warnings{end+1} = sprintf( ...
        'Duplicate clipped u_0 values were removed. Requested points: %d. Accepted points: %d.', ...
        numel(requested_u0_kt), numel(accepted_u0_kt));
end

% Ensure the exact baseline speed is present. The default factors include 1.00,
% but this protects custom sweeps.
if ~any(abs(accepted_u0_kt - baseline_u0_kt) <= max(tol, tol*baseline_u0_kt))
    accepted_u0_kt(end+1) = baseline_u0_kt;
    accepted_u0_kt = sort(accepted_u0_kt);
    accepted_factors = accepted_u0_kt ./ baseline_u0_kt;
    accepted_mach = accepted_u0_kt ./ speed_of_sound_kt;
    warnings{end+1} = 'Baseline u_0 was not in the requested sweep and was added automatically.';
end

if baseline_u0_kt > u0_cap_kt + tol
    warnings{end+1} = sprintf( ...
        'Baseline u_0 itself exceeds the Mach %.3f cap. Check the aircraft case inputs.', mach_cap);
end

sweep = struct();
sweep.parameter_name = 'u_0';
sweep.units = 'knots';
sweep.baseline_u0_kt = baseline_u0_kt;
sweep.requested_factors = sweep_factors(:).';
sweep.requested_u0_kt = requested_u0_kt;
sweep.requested_mach = requested_mach;
sweep.accepted_factors = accepted_factors(:).';
sweep.accepted_u0_kt = accepted_u0_kt(:).';
sweep.accepted_mach = accepted_mach(:).';
sweep.mach_cap = mach_cap;
sweep.speed_of_sound_kt = speed_of_sound_kt;
sweep.u0_cap_kt = u0_cap_kt;
sweep.was_clipped = was_clipped;
sweep.keep_idx_after_clipping = keep_idx(:).';
sweep.warnings = warnings;

end

function value = local_get_option(options, field_name, default_value)
if isstruct(options) && isfield(options, field_name) && ~isempty(options.(field_name))
    value = options.(field_name);
else
    value = default_value;
end
end

function u0_kt = local_get_u0_knots(pAV)
u0_kt = NaN;
if ~isstruct(pAV)
    return;
end
if isfield(pAV, 'u0_kt') && isnumeric(pAV.u0_kt) && isscalar(pAV.u0_kt)
    u0_kt = pAV.u0_kt;
elseif isfield(pAV, 'u0') && isnumeric(pAV.u0) && isscalar(pAV.u0)
    % In the current AVS input files, pAV.u0 is stored in knots.
    u0_kt = pAV.u0;
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
