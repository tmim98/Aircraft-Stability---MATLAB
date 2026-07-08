function pSI = lateral_input_AVS_to_SI_snapshot(pAV)
%LATERAL_INPUT_AVS_TO_SI_SNAPSHOT Convert lateral/directional input snapshot to SI.
%
% This helper is for reporting/export only. It does not run the lateral core
% and it does not change the existing AVS-based lateral analysis path.
%
% Current purpose:
%   AVS lateral input struct  ->  SI lateral input snapshot
%
% Later use:
%   out.inputs_SI.lateral_directional = lateral_input_AVS_to_SI_snapshot(lat_pAV);
%
% Notes:
%   1) Dimensionless aerodynamic coefficients are copied without conversion.
%   2) Radian angles are copied without conversion.
%   3) Sweep/dihedral fields currently stored in degrees are copied as-is.
%   4) File paths and text metadata are copied as-is.
%   5) Generic dimensional field names are converted in place:
%          u0, rho, W, S, b, c_bar, Ix, ...
%   6) Explicit AVS-suffix fields are renamed when converted:
%          altitude_ft -> altitude_m
%          qbar_psf    -> qbar_Pa

if nargin < 1 || ~isstruct(pAV)
    error('lateral_input_AVS_to_SI_snapshot:BadInput', ...
        'Input must be a scalar lateral/directional pAV struct.');
end

if ~isscalar(pAV)
    error('lateral_input_AVS_to_SI_snapshot:NonScalarInput', ...
        'Input pAV must be a scalar struct.');
end

pSI = pAV;

original_unit_system = local_get_unit_system(pAV);

pSI.units = 'SI';
pSI.input_unit_system = 'SI';
pSI.source_input_unit_system = original_unit_system;
pSI.unit_conversion_note = ['SI snapshot converted from lateral/directional ', ...
    'input data. This struct is for reporting/export only; it is not used ', ...
    'by the current AVS lateral analysis core.'];

if ~strcmpi(original_unit_system, 'AVS')
    pSI.unit_conversion_note = ['Input was not declared as AVS, so this ', ...
        'helper only labeled the snapshot as SI and copied values unchanged.'];
    return;
end

% ================= FLIGHT CONDITION =================
pSI = local_convert_existing_field(pSI, 'u0',  'kt_to_mps');
pSI = local_convert_existing_field(pSI, 'rho', 'slugft3_to_kgm3');

if isfield(pSI, 'g') && local_is_numeric_value(pSI.g)
    % ft/s^2 -> m/s^2; seconds are unchanged, so the length factor applies.
    pSI.g = aircraft_unit_convert(pSI.g, 'ft_to_m');
end

if isfield(pSI, 'nu') && local_is_numeric_value(pSI.nu)
    % ft^2/s -> m^2/s; seconds are unchanged, so the area factor applies.
    pSI.nu = aircraft_unit_convert(pSI.nu, 'ft2_to_m2');
end

% Explicit AVS-suffix fields converted to clean SI-suffix names.
if isfield(pSI, 'altitude_ft') && local_is_numeric_value(pSI.altitude_ft)
    pSI.altitude_m = aircraft_unit_convert(pSI.altitude_ft, 'ft_to_m');
    pSI = rmfield(pSI, 'altitude_ft');
end

if isfield(pSI, 'qbar_psf') && local_is_numeric_value(pSI.qbar_psf)
    pSI.qbar_Pa = aircraft_unit_convert(pSI.qbar_psf, 'psf_to_pa');
    pSI = rmfield(pSI, 'qbar_psf');
end

% ================= MASS / INERTIA =================
pSI = local_convert_existing_field(pSI, 'W',   'lbf_to_n');
pSI = local_convert_existing_field(pSI, 'Ix',  'slugft2_to_kgm2');
pSI = local_convert_existing_field(pSI, 'Iy',  'slugft2_to_kgm2');
pSI = local_convert_existing_field(pSI, 'Iz',  'slugft2_to_kgm2');
pSI = local_convert_existing_field(pSI, 'Ixz', 'slugft2_to_kgm2');
pSI = local_convert_existing_field(pSI, 'Iyy', 'slugft2_to_kgm2');

% ================= AREAS =================
area_fields = { ...
    'S', ...
    'St', ...
    'Sv', ...
    'S_v', ...
    'S_fs' ...
    };

for k = 1:numel(area_fields)
    pSI = local_convert_existing_field(pSI, area_fields{k}, 'ft2_to_m2');
end

% ================= LENGTHS =================
length_fields = { ...
    'b', ...
    'c_bar', ...
    'x_cg', ...
    'x_ac', ...
    'c_root', ...
    'c_tip', ...
    'y1', ...
    'y2', ...
    'lt', ...
    'lv', ...
    'l_v', ...
    'bv', ...
    'zv', ...
    'z_w', ...
    'd', ...
    'l_f', ...
    'x_m', ...
    'h', ...
    'h1', ...
    'h2', ...
    'w_f' ...
    };

for k = 1:numel(length_fields)
    pSI = local_convert_existing_field(pSI, length_fields{k}, 'ft_to_m');
end

end

function p = local_convert_existing_field(p, field_name, conversion_name)
%LOCAL_CONVERT_EXISTING_FIELD Convert one numeric field when it exists.

if isfield(p, field_name) && local_is_numeric_value(p.(field_name))
    p.(field_name) = aircraft_unit_convert(p.(field_name), conversion_name);
end

end

function tf = local_is_numeric_value(x)
%LOCAL_IS_NUMERIC_VALUE True for numeric/logical values that can be converted.

tf = (isnumeric(x) || islogical(x)) && ~isempty(x);

end

function unit_system = local_get_unit_system(p)
%LOCAL_GET_UNIT_SYSTEM Read preferred unit-system metadata.

unit_system = '';

if isfield(p, 'input_unit_system') && ~isempty(p.input_unit_system)
    unit_system = p.input_unit_system;

elseif isfield(p, 'units') && ~isempty(p.units)
    unit_system = p.units;
end

if isstring(unit_system)
    unit_system = char(unit_system);
end

if ~ischar(unit_system)
    unit_system = '';
end

unit_system = strtrim(unit_system);

end