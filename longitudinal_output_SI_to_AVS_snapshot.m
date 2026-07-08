function outAVS = longitudinal_output_SI_to_AVS_snapshot(outSI)
%LONGITUDINAL_OUTPUT_SI_TO_AVS_SNAPSHOT Convert longitudinal SI output to AVS.
%
% This helper is for reporting/export only. It does not run the longitudinal
% core and it does not change the existing SI-based longitudinal analysis path.
%
% Current purpose:
%   SI longitudinal output struct  ->  AVS longitudinal output snapshot
%
% Later use:
%   out.longitudinal_outputs_AVS = longitudinal_output_SI_to_AVS_snapshot(long_out);
%
% Conversion policy:
%   1) Dimensionless aerodynamic coefficients are copied unchanged.
%   2) Eigenvalues, damping ratios, natural frequencies, and time constants
%      are copied unchanged because their units are based on seconds.
%   3) Scalar dimensional quantities with unambiguous units are converted.
%   4) The 4-by-4 longitudinal A matrix is converted by state scaling:
%          x_SI  = [Delta_u_mps;  Delta_w_mps;  Delta_q_rps; Delta_theta]
%          x_AVS = [Delta_u_ftps; Delta_w_ftps; Delta_q_rps; Delta_theta]
%      so:
%          A_AVS = T * A_SI / T
%   5) The longitudinal B matrix is converted by output-state scaling:
%          B_AVS = T * B_SI
%      because the current control inputs are angular/dimensionless.

if nargin < 1 || ~isstruct(outSI)
    error('longitudinal_output_SI_to_AVS_snapshot:BadInput', ...
        'Input must be a scalar longitudinal SI output struct.');
end

if ~isscalar(outSI)
    error('longitudinal_output_SI_to_AVS_snapshot:NonScalarInput', ...
        'Input outSI must be a scalar struct.');
end

outAVS = outSI;

outAVS.output_unit_system = 'AVS';
outAVS.source_output_unit_system = 'SI';
outAVS.unit_conversion_note = ['AVS snapshot converted from longitudinal SI ', ...
    'analysis output. This struct is for reporting/export only; it is not ', ...
    'used by the current longitudinal analysis core.'];

outAVS.unit_conversion_policy = struct();
outAVS.unit_conversion_policy.length = 'm -> ft';
outAVS.unit_conversion_policy.velocity = 'm/s -> ft/s';
outAVS.unit_conversion_policy.acceleration = 'm/s^2 -> ft/s^2';
outAVS.unit_conversion_policy.state_space = ...
    'A and B converted by longitudinal state scaling for [Delta_u, Delta_w, Delta_q, Delta_theta].';
outAVS.unit_conversion_policy.dimensionless = ...
    'Dimensionless coefficients, radian quantities, eigenvalues, frequencies, and damping ratios are copied unchanged.';

% -------------------------------------------------------------------------
% Convert known scalar dimensional fields.
% -------------------------------------------------------------------------
outAVS = local_convert_scalar_field(outAVS, 'x_NP', 'm_to_ft');

% Z_alpha and Z_deltaE are acceleration-like derivatives per radian input.
outAVS = local_convert_scalar_field(outAVS, 'Z_alpha',  'm_to_ft');
outAVS = local_convert_scalar_field(outAVS, 'Z_deltaE', 'm_to_ft');

% Z_q is velocity-like in the current longitudinal state equation.
outAVS = local_convert_scalar_field(outAVS, 'Z_q', 'm_to_ft');

% M_u and M_w multiply velocity perturbations. Converting the velocity state
% from m/s to ft/s changes these coefficients by ft-to-m.
outAVS = local_convert_velocity_slope_field(outAVS, 'M_u');
outAVS = local_convert_velocity_slope_field(outAVS, 'M_w');

% -------------------------------------------------------------------------
% Convert state-space matrices when they are available.
% -------------------------------------------------------------------------
if isfield(outAVS, 'A') && isnumeric(outAVS.A) && isequal(size(outAVS.A), [4 4])
    outAVS.A = local_convert_longitudinal_A_SI_to_AVS(outAVS.A);
end

if isfield(outAVS, 'B') && isnumeric(outAVS.B) && size(outAVS.B, 1) == 4
    outAVS.B = local_convert_longitudinal_B_SI_to_AVS(outAVS.B);
end

% -------------------------------------------------------------------------
% Preserve original native SI output as traceability metadata only when
% users inspect the struct manually. This is deliberately not a deep copy of
% the whole SI struct, to avoid bloating future Excel exports.
% -------------------------------------------------------------------------
outAVS.native_output_reference = 'Original native SI output remains available as out.longitudinal_outputs_SI.';

end

function s = local_convert_scalar_field(s, field_name, conversion_name)
%LOCAL_CONVERT_SCALAR_FIELD Convert one scalar numeric field when present.

if isfield(s, field_name) && local_is_numeric_scalar(s.(field_name))
    s.(field_name) = aircraft_unit_convert(s.(field_name), conversion_name);
end

end

function s = local_convert_velocity_slope_field(s, field_name)
%LOCAL_CONVERT_VELOCITY_SLOPE_FIELD Convert coefficient per velocity state.
%
% If qdot = M_u_SI * u_mps = M_u_AVS * u_ftps,
% and u_ftps = u_mps / 0.3048, then:
%
%   M_u_AVS = M_u_SI * 0.3048

if isfield(s, field_name) && local_is_numeric_scalar(s.(field_name))
    s.(field_name) = aircraft_unit_convert(s.(field_name), 'ft_to_m');
end

end

function tf = local_is_numeric_scalar(x)
%LOCAL_IS_NUMERIC_SCALAR True for scalar numeric/logical values.

tf = (isnumeric(x) || islogical(x)) && isscalar(x) && ~isempty(x);

end

function A_avs = local_convert_longitudinal_A_SI_to_AVS(A_si)
%LOCAL_CONVERT_LONGITUDINAL_A_SI_TO_AVS Convert 4-state longitudinal A matrix.
%
% SI state:
%   x_SI  = [Delta_u_mps; Delta_w_mps; Delta_q_radps; Delta_theta_rad]
%
% AVS state:
%   x_AVS = [Delta_u_ftps; Delta_w_ftps; Delta_q_radps; Delta_theta_rad]
%
% x_AVS = T*x_SI
% A_AVS = T*A_SI/T

mps_to_ftps = aircraft_unit_convert(1, 'm_to_ft');

T = diag([mps_to_ftps, mps_to_ftps, 1, 1]);

A_avs = T * A_si / T;

end

function B_avs = local_convert_longitudinal_B_SI_to_AVS(B_si)
%LOCAL_CONVERT_LONGITUDINAL_B_SI_TO_AVS Convert longitudinal B matrix rows.
%
% The current longitudinal control inputs are angular/dimensionless. Therefore
% only the output state scaling is needed:
%
%   B_AVS = T*B_SI

mps_to_ftps = aircraft_unit_convert(1, 'm_to_ft');

T = diag([mps_to_ftps, mps_to_ftps, 1, 1]);

B_avs = T * B_si;

end