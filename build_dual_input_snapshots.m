function [inputs_SI, inputs_AVS] = build_dual_input_snapshots(long_pAV, long_pSI, lat_pAV)
%BUILD_DUAL_INPUT_SNAPSHOTS Build standardized SI and AVS input containers.
%
% This helper creates the new input-output structure requested for the unit
% system expansion:
%
%   out.inputs_SI
%   out.inputs_AVS
%
% Current behavior:
%   inputs_AVS.longitudinal          = original longitudinal AVS input struct
%   inputs_AVS.lateral_directional   = original lateral/directional AVS input struct
%   inputs_SI.longitudinal           = existing converted longitudinal SI struct
%   inputs_SI.lateral_directional    = SI snapshot converted from lateral AVS input
%
% Important:
%   1) This helper does not run either analysis core.
%   2) This helper does not change any current numerical result.
%   3) The lateral SI struct is a reporting/export snapshot only.
%   4) The old runner fields out.inputs.* should remain available for
%      compatibility until the whole unit-system transition is complete.

if nargin < 3
    error('build_dual_input_snapshots:MissingInputs', ...
        'Use build_dual_input_snapshots(long_pAV, long_pSI, lat_pAV).');
end

if ~isstruct(long_pAV) || ~isscalar(long_pAV)
    error('build_dual_input_snapshots:BadLongAVS', ...
        'long_pAV must be a scalar struct.');
end

if ~isstruct(long_pSI) || ~isscalar(long_pSI)
    error('build_dual_input_snapshots:BadLongSI', ...
        'long_pSI must be a scalar struct.');
end

if ~isstruct(lat_pAV) || ~isscalar(lat_pAV)
    error('build_dual_input_snapshots:BadLatAVS', ...
        'lat_pAV must be a scalar struct.');
end

inputs_AVS = struct();
inputs_SI  = struct();

inputs_AVS.longitudinal = long_pAV;
inputs_AVS.lateral_directional = lat_pAV;

inputs_SI.longitudinal = long_pSI;
inputs_SI.lateral_directional = lateral_input_AVS_to_SI_snapshot(lat_pAV);

inputs_AVS.meta = local_make_inputs_meta('AVS', long_pAV, lat_pAV);
inputs_SI.meta  = local_make_inputs_meta('SI',  long_pAV, lat_pAV);

end

function meta = local_make_inputs_meta(unit_system, long_pAV, lat_pAV)
%LOCAL_MAKE_INPUTS_META Metadata attached to each standardized input snapshot.

meta = struct();

meta.unit_system = unit_system;
meta.created = char(datetime('now'));
meta.note = ['Standardized input snapshot created for reporting/export. ', ...
    'The analysis cores still use their existing internal unit systems.'];

meta.longitudinal_source_unit_system = local_get_declared_unit_system(long_pAV);
meta.lateral_directional_source_unit_system = local_get_declared_unit_system(lat_pAV);

end

function unit_system = local_get_declared_unit_system(p)
%LOCAL_GET_DECLARED_UNIT_SYSTEM Read preferred unit-system metadata.

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

if isempty(unit_system)
    unit_system = 'UNSPECIFIED';
end

end