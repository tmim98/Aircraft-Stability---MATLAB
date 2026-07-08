function y = aircraft_unit_convert(x, conversion_name)
%AIRCRAFT_UNIT_CONVERT Reusable SI/AVS scalar unit-conversion helper.
%
% Usage:
%   y = aircraft_unit_convert(x, 'ft_to_m');
%   y = aircraft_unit_convert(x, 'm_to_ft');
%
% To inspect all conversion factors:
%   factors = aircraft_unit_convert();
%
% This helper intentionally converts only numeric values. It does not decide
% which aircraft fields should be converted. That field-mapping logic belongs
% in later input/output conversion wrappers.
%
% Supported conversions:
%   Length      : ft <-> m
%   Area        : ft^2 <-> m^2
%   Volume      : ft^3 <-> m^3
%   Speed       : kt <-> m/s
%   Force       : lbf <-> N
%   Mass        : slug <-> kg
%   Inertia     : slug*ft^2 <-> kg*m^2
%   Density     : slug/ft^3 <-> kg/m^3
%   Pressure    : psf <-> Pa
%   Angle rate  : rad/s <-> deg/s
%
% Dimensionless aerodynamic coefficients are not converted by this helper.

f = local_unit_factors();

if nargin == 0
    y = f;
    return;
end

if nargin ~= 2
    error('aircraft_unit_convert:InvalidInputCount', ...
        'Use either aircraft_unit_convert() or aircraft_unit_convert(x, conversion_name).');
end

if ~(isnumeric(x) || islogical(x))
    error('aircraft_unit_convert:NonNumericInput', ...
        'Input value x must be numeric or logical.');
end

if isstring(conversion_name)
    conversion_name = char(conversion_name);
end

if ~ischar(conversion_name)
    error('aircraft_unit_convert:InvalidConversionName', ...
        'conversion_name must be a character vector or string.');
end

switch lower(strtrim(conversion_name))

    % ----- length -----
    case 'ft_to_m'
        y = x * f.FT2M;

    case 'm_to_ft'
        y = x / f.FT2M;

    % ----- area -----
    case 'ft2_to_m2'
        y = x * f.FT2_TO_M2;

    case 'm2_to_ft2'
        y = x / f.FT2_TO_M2;

    % ----- volume -----
    case 'ft3_to_m3'
        y = x * f.FT3_TO_M3;

    case 'm3_to_ft3'
        y = x / f.FT3_TO_M3;

    % ----- speed -----
    case {'kt_to_mps', 'knot_to_mps', 'knots_to_mps'}
        y = x * f.KT2MPS;

    case {'mps_to_kt', 'mps_to_knot', 'mps_to_knots'}
        y = x / f.KT2MPS;

    % ----- force / weight -----
    case 'lbf_to_n'
        y = x * f.LBF2N;

    case 'n_to_lbf'
        y = x / f.LBF2N;

    % ----- mass -----
    case 'slug_to_kg'
        y = x * f.SLUG2KG;

    case 'kg_to_slug'
        y = x / f.SLUG2KG;

    % ----- inertia -----
    case 'slugft2_to_kgm2'
        y = x * f.SLUGFT2_TO_KGM2;

    case 'kgm2_to_slugft2'
        y = x / f.SLUGFT2_TO_KGM2;

    % ----- density -----
    case 'slugft3_to_kgm3'
        y = x * f.SLUGFT3_TO_KGM3;

    case 'kgm3_to_slugft3'
        y = x / f.SLUGFT3_TO_KGM3;

    % ----- pressure / dynamic pressure -----
    case 'psf_to_pa'
        y = x * f.PSF2PA;

    case 'pa_to_psf'
        y = x / f.PSF2PA;

    % ----- angle-rate display conversions -----
    case 'rads_to_degs'
        y = x * f.RAD2DEG;

    case 'degs_to_rads'
        y = x / f.RAD2DEG;

    otherwise
        error('aircraft_unit_convert:UnknownConversion', ...
            'Unknown conversion name: %s', conversion_name);
end

end

function f = local_unit_factors()
%LOCAL_UNIT_FACTORS Centralized constants for SI/AVS conversion.

f = struct();

f.FT2M    = 0.3048;
f.KT2MPS  = 0.514444444444444;
f.LBF2N   = 4.4482216152605;
f.SLUG2KG = 14.59390294;
f.RAD2DEG = 180/pi;

f.FT2_TO_M2 = f.FT2M^2;
f.FT3_TO_M3 = f.FT2M^3;

f.SLUGFT2_TO_KGM2 = f.SLUG2KG * f.FT2_TO_M2;
f.SLUGFT3_TO_KGM3 = f.SLUG2KG / f.FT3_TO_M3;

f.PSF2PA = f.LBF2N / f.FT2_TO_M2;

end