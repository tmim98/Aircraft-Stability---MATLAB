function catalog = get_parametric_parameter_catalog()
% GET_PARAMETRIC_PARAMETER_CATALOG Return implemented parametric variables.
%
% Purpose:
%   Central catalog for the parametric-analysis workflow.
%
%   The current user-facing script, run_parametric_analysis.m, uses this
%   catalog to build its parameter-selection dialog. A future App Designer
%   interface can use the same catalog to populate a listbox/dropdown without
%   duplicating parameter names, folder names, or descriptions.
%
% Current design:
%   - Each catalog entry represents one implemented one-dimensional sweep.
%   - Multiple selected entries are currently run as multiple independent
%     one-dimensional sweeps from the same baseline aircraft case.
%   - Coupled multi-variable sweeps are intentionally not represented as
%     implemented here yet.
%
% Fields:
%   key                         Stable short identifier.
%   parameter_name              Backend name passed to run_parametric_sweep.m.
%   display_name                User-facing name.
%   folder_name                 Results-folder name under Parametric/.
%   workbook_file_name          Default workbook filename.
%   short_description           Short selector text.
%   analysis_branch             Expected branch behavior.
%   implemented                 True if available in the current backend.
%   supports_one_dimensional    True for current sweep implementation.
%   supports_coupled_sweep      Reserved for future multi-variable sweeps.
%   notes                       Human-readable implementation notes.

catalog = repmat(local_empty_entry(), 2, 1);

catalog(1).key = 'u0';
catalog(1).parameter_name = 'u_0';
catalog(1).display_name = 'u_0';
catalog(1).folder_name = 'u_0';
catalog(1).workbook_file_name = 'u_0_parametric_summary.xlsx';
catalog(1).short_description = 'true airspeed sweep';
catalog(1).analysis_branch = 'both longitudinal and lateral/directional';
catalog(1).implemented = true;
catalog(1).supports_one_dimensional = true;
catalog(1).supports_coupled_sweep = false;
catalog(1).notes = [ ...
    'Sweeps true airspeed, applies Mach-cap logic, recomputes qbar, ', ...
    'updates CL0 using baseline-preserving trim scaling, synchronizes ', ...
    'lateral CL aliases, and updates Mach-derived speed derivatives when ', ...
    'source fields exist.'];

catalog(2).key = 'xcg';
catalog(2).parameter_name = 'x_cg';
catalog(2).display_name = 'x_cg / cg_mac';
catalog(2).folder_name = 'x_cg';
catalog(2).workbook_file_name = 'x_cg_parametric_summary.xlsx';
catalog(2).short_description = 'center-of-gravity sweep';
catalog(2).analysis_branch = 'longitudinal only';
catalog(2).implemented = true;
catalog(2).supports_one_dimensional = true;
catalog(2).supports_coupled_sweep = false;
catalog(2).notes = [ ...
    'Sweeps cg_mac = x_cg/c_bar, applies safety limits, preserves the ', ...
    'fixed horizontal-tail reference station, recomputes lt and V_H, ', ...
    'updates Cm_alpha with a baseline-preserving relation, and tracks ', ...
    'primary/secondary static-stability methods and critical-CG estimates.'];

end

function entry = local_empty_entry()
entry = struct();
entry.key = '';
entry.parameter_name = '';
entry.display_name = '';
entry.folder_name = '';
entry.workbook_file_name = '';
entry.short_description = '';
entry.analysis_branch = '';
entry.implemented = false;
entry.supports_one_dimensional = false;
entry.supports_coupled_sweep = false;
entry.notes = '';
end
