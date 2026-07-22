function outSI = lateral_output_AVS_to_SI_snapshot(outAVS)
%LATERAL_OUTPUT_AVS_TO_SI_SNAPSHOT Convert lateral/directional AVS output to SI.
%
% This helper is for reporting/export only. It does not run the lateral core
% and it does not change the existing AVS-based lateral analysis path.
%
% Current purpose:
%   AVS lateral/directional output struct  ->  SI lateral/directional output snapshot
%
% Later use:
%   out.lateral_outputs_SI = lateral_output_AVS_to_SI_snapshot(lat_out);
%
% Conversion policy:
%   1) Dimensionless aerodynamic coefficients are copied unchanged.
%   2) Eigenvalues, damping ratios, natural frequencies, time constants, and
%      the beta-based lateral state-space A/B matrices are copied unchanged
%      because their states are beta, p, r, phi and their controls are angles.
%   3) Flight-condition, geometry, inertia, scale, dimensional-force, and
%      dimensional-moment quantities with unambiguous AVS units are converted.
%   4) Deep diagnostic fields whose units are ambiguous are copied unchanged.

if nargin < 1 || ~isstruct(outAVS)
    error('lateral_output_AVS_to_SI_snapshot:BadInput', ...
        'Input must be a scalar lateral/directional AVS output struct.');
end

if ~isscalar(outAVS)
    error('lateral_output_AVS_to_SI_snapshot:NonScalarInput', ...
        'Input outAVS must be a scalar struct.');
end

outSI = outAVS;

outSI.output_unit_system = 'SI';
outSI.source_output_unit_system = 'AVS';
outSI.unit_conversion_note = ['SI snapshot converted from lateral/directional AVS ', ...
    'analysis output. This struct is for reporting/export only; it is not ', ...
    'used by the current lateral/directional analysis core.'];

outSI.unit_conversion_policy = struct();
outSI.unit_conversion_policy.length = 'ft -> m';
outSI.unit_conversion_policy.area = 'ft^2 -> m^2';
outSI.unit_conversion_policy.speed = 'kt or ft/s -> m/s, depending on source field';
outSI.unit_conversion_policy.force = 'lbf -> N';
outSI.unit_conversion_policy.moment = 'lbf*ft -> N*m';
outSI.unit_conversion_policy.mass = 'slug -> kg';
outSI.unit_conversion_policy.inertia = 'slug*ft^2 -> kg*m^2';
outSI.unit_conversion_policy.state_space = ...
    'A_lat and B_lat are copied unchanged because beta, p, r, phi, delta_a, and delta_r are unit-invariant.';
outSI.unit_conversion_policy.dimensionless = ...
    'Dimensionless coefficients, radian quantities, eigenvalues, frequencies, and damping ratios are copied unchanged.';

if isfield(outSI, 'meta') && isstruct(outSI.meta)
    outSI.meta.units = 'SI';
else
    outSI.meta = struct();
    outSI.meta.units = 'SI';
end

% -------------------------------------------------------------------------
% Flight condition.
% -------------------------------------------------------------------------
outSI = local_convert_dot_path(outSI, 'flight_condition.u0',    'kt_to_mps');
outSI = local_convert_dot_path(outSI, 'flight_condition.rho',   'slugft3_to_kgm3');
outSI = local_convert_dot_path(outSI, 'flight_condition.W',     'lbf_to_n');
outSI = local_convert_dot_path(outSI, 'flight_condition.m',     'slug_to_kg');
outSI = local_convert_dot_path(outSI, 'flight_condition.qbar',  'psf_to_pa');
outSI = local_convert_dot_path(outSI, 'flight_condition.g',     'ft_to_m');

% Explicit AVS-suffix speed field: ft/s -> m/s, with an SI-suffix name.
if local_has_dot_path(outSI, 'flight_condition.u0_fps')
    u0_fps = local_get_dot_path(outSI, 'flight_condition.u0_fps');
    if local_is_numeric_value(u0_fps)
        outSI = local_set_dot_path(outSI, 'flight_condition.u0_mps', ...
            aircraft_unit_convert(u0_fps, 'ft_to_m'));
        outSI = local_remove_dot_path(outSI, 'flight_condition.u0_fps');
    end
end

% -------------------------------------------------------------------------
% Geometry and inertia.
% -------------------------------------------------------------------------
outSI = local_convert_dot_path(outSI, 'geometry.S',     'ft2_to_m2');
outSI = local_convert_dot_path(outSI, 'geometry.b',     'ft_to_m');
outSI = local_convert_dot_path(outSI, 'geometry.c_bar', 'ft_to_m');

outSI = local_convert_dot_path(outSI, 'inertia.Ix',  'slugft2_to_kgm2');
outSI = local_convert_dot_path(outSI, 'inertia.Iz',  'slugft2_to_kgm2');
outSI = local_convert_dot_path(outSI, 'inertia.Ixz', 'slugft2_to_kgm2');

% -------------------------------------------------------------------------
% Dimensional scale factors.
% -------------------------------------------------------------------------
% rateScale = b/(2*u0), so it is time-based and unchanged.
outSI = local_convert_dot_path(outSI, 'scale.QS',  'lbf_to_n');
outSI = local_convert_dot_path(outSI, 'scale.QSb', 'lbf_ft_to_nm');

% -------------------------------------------------------------------------
% Dimensional force and moment derivatives.
% -------------------------------------------------------------------------
force_derivative_fields = { ...
    'dimensional.Y_beta', ...
    'dimensional.Y_p', ...
    'dimensional.Y_r', ...
    'dimensional.Y_delta_a', ...
    'dimensional.Y_delta_r' ...
    };

for k = 1:numel(force_derivative_fields)
    outSI = local_convert_dot_path(outSI, force_derivative_fields{k}, 'lbf_to_n');
end

moment_derivative_fields = { ...
    'dimensional.L_beta', ...
    'dimensional.L_p', ...
    'dimensional.L_r', ...
    'dimensional.L_delta_a', ...
    'dimensional.L_delta_r', ...
    'dimensional.N_beta', ...
    'dimensional.N_p', ...
    'dimensional.N_r', ...
    'dimensional.N_delta_a', ...
    'dimensional.N_delta_r' ...
    };

for k = 1:numel(moment_derivative_fields)
    outSI = local_convert_dot_path(outSI, moment_derivative_fields{k}, 'lbf_ft_to_nm');
end

% -------------------------------------------------------------------------
% Normalized lateral-force quantities.
% -------------------------------------------------------------------------
% These Y/m quantities carry length in the numerator. Values that are already
% divided by u0 and therefore appear directly in B_lat are left unchanged.
y_over_m_fields = { ...
    'normalized.Y_beta_over_m', ...
    'normalized.Y_p_over_m', ...
    'normalized.Y_r_over_m', ...
    'normalized.Y_delta_a_over_m', ...
    'normalized.Y_delta_r_over_m_raw' ...
    };

for k = 1:numel(y_over_m_fields)
    outSI = local_convert_dot_path(outSI, y_over_m_fields{k}, 'ft_to_m');
end

% L/I and N/I normalized quantities are time-based, so they remain unchanged.
% A_lat, B_lat, eigenvalues, modal classifications, damping ratios, and
% approximate roots also remain unchanged.

% -------------------------------------------------------------------------
% Aileron diagnostic geometry integral, when present.
% -------------------------------------------------------------------------
% integral_cy is the dimensional integral of c*y dy used in the aileron
% effectiveness estimate, so its AVS unit is ft^3.
outSI = local_convert_dot_path(outSI, 'control_power.aileron.info.integral_cy', 'ft3_to_m3');

outSI.native_output_reference = 'Original native AVS output remains available as out.lateral_outputs_AVS.';

end

function s = local_convert_dot_path(s, dot_path, conversion_name)
%LOCAL_CONVERT_DOT_PATH Convert one nested numeric field when present.

if ~local_has_dot_path(s, dot_path)
    return;
end

x = local_get_dot_path(s, dot_path);

if local_is_numeric_value(x)
    s = local_set_dot_path(s, dot_path, local_apply_conversion(x, conversion_name));
end

end

function y = local_apply_conversion(x, conversion_name)
%LOCAL_APPLY_CONVERSION Apply scalar/vector conversion by name.

switch lower(strtrim(conversion_name))
    case 'lbf_ft_to_nm'
        y = aircraft_unit_convert(aircraft_unit_convert(x, 'lbf_to_n'), 'ft_to_m');

    otherwise
        y = aircraft_unit_convert(x, conversion_name);
end

end

function tf = local_is_numeric_value(x)
%LOCAL_IS_NUMERIC_VALUE True for numeric/logical values that can be converted.

tf = (isnumeric(x) || islogical(x)) && ~isempty(x);

end

function tf = local_has_dot_path(s, dot_path)
%LOCAL_HAS_DOT_PATH True when all fields in a nested dot path exist.

parts = strsplit(dot_path, '.');
tf = true;
current = s;

for k = 1:numel(parts)
    field_name = parts{k};

    if ~isstruct(current) || ~isscalar(current) || ~isfield(current, field_name)
        tf = false;
        return;
    end

    current = current.(field_name);
end

end

function value = local_get_dot_path(s, dot_path)
%LOCAL_GET_DOT_PATH Read a nested dot-path value.

parts = strsplit(dot_path, '.');
value = s;

for k = 1:numel(parts)
    value = value.(parts{k});
end

end

function s = local_set_dot_path(s, dot_path, value)
%LOCAL_SET_DOT_PATH Set a nested dot-path value in scalar structs.

parts = strsplit(dot_path, '.');
s = local_set_dot_path_parts(s, parts, value);

end

function s = local_set_dot_path_parts(s, parts, value)
%LOCAL_SET_DOT_PATH_PARTS Recursive implementation of local_set_dot_path.

field_name = parts{1};

if isscalar(parts)
    s.(field_name) = value;
    return;
end

if ~isfield(s, field_name) || ~isstruct(s.(field_name)) || ~isscalar(s.(field_name))
    s.(field_name) = struct();
end

s.(field_name) = local_set_dot_path_parts(s.(field_name), parts(2:end), value);

end

function s = local_remove_dot_path(s, dot_path)
%LOCAL_REMOVE_DOT_PATH Remove a nested field when present.

parts = strsplit(dot_path, '.');
s = local_remove_dot_path_parts(s, parts);

end

function s = local_remove_dot_path_parts(s, parts)
%LOCAL_REMOVE_DOT_PATH_PARTS Recursive implementation of local_remove_dot_path.

field_name = parts{1};

if ~isstruct(s) || ~isscalar(s) || ~isfield(s, field_name)
    return;
end

if isscalar(parts)
    s = rmfield(s, field_name);
    return;
end

s.(field_name) = local_remove_dot_path_parts(s.(field_name), parts(2:end));

end