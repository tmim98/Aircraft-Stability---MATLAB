# Parametric Parameter Map

## A. Purpose

This document defines which aircraft inputs are available for parametric analysis, how each input is varied, what dependent quantities must be recomputed, and which outputs should be tracked.

The parameter map must be defined before generalized parametric-analysis code is written.

The current implemented parametric-analysis variable is:

```text
u_0
```

---

## B. Parameter Classification Rules

### B.1 Canonical names

Duplicate names should be avoided.

Use:

```text
x_cg instead of cg
x_ac instead of ac
m instead of W, unless W is deliberately chosen as the primary input
```

### B.2 Sweepable parameter

A sweepable parameter is an input that can be varied over a chosen range while the analysis is rerun at each value.

Example:

```text
x_cg baseline value: 0.75 m

sweep values:
    0.65
    0.70
    0.75
    0.80
    0.85
```

For each value, the code updates the selected parameter, reruns the analysis, and stores the resulting derivatives, matrices, eigenvalues, mode metrics, and stability flags.

### B.3 Hold-fixed/recompute policy

Geometry-related parameters must define which quantities remain fixed and which quantities are recomputed.

Example:

```text
if S changes:
    hold b fixed unless otherwise specified
    hold c_bar fixed unless otherwise specified
    recompute AR = b^2/S
```

This prevents geometry-sensitive parameters from being varied blindly.

---

## C. Implementation Status

### C.1 Implemented parameters

The implemented parametric-analysis variables are:

```text
u_0
x_cg / cg_mac
```

The shared implementation consists of:

```text
build_u0_sweep_values.m
build_xcg_sweep_values.m
apply_parametric_variation.m
run_parametric_sweep.m
export_parametric_workbook.m
plot_parametric_results.m
run_parametric_analysis.m
```

The user-facing entry point is:

```text
run_parametric_analysis.m
```

The direct backend entry point is:

```text
run_parametric_sweep.m
```

### C.2 Implemented output paths

For each selected aircraft, parametric-analysis output is saved under a parameter-specific folder:

```text
results\<AIRCRAFT_CASE>\Parametric\u_0\
results\<AIRCRAFT_CASE>\Parametric\x_cg\
```

Each output folder contains a workbook and a plot folder, for example:

```text
u_0_parametric_summary.xlsx
x_cg_parametric_summary.xlsx
plots\
```

### C.3 Implemented `u_0` policy

The implemented `u_0` sweep uses the following policy:

1. Generate candidate `u_0` sweep values around the baseline speed.
2. Enforce a hard Mach cap:

```text
M <= 0.9
```

3. Clip or remove values above the Mach cap.
4. Keep `rho`, `S`, and mass/weight fixed during the sweep.
5. Recompute dynamic pressure:

```text
qbar = 0.5*rho*u_0^2
```

6. Update `CL0` using baseline-preserving trim-consistent scaling:

```text
CL0_new = CL0_baseline * (qbar_baseline/qbar_new)
```

Equivalently, when `rho` and `S` are fixed:

```text
CL0_new = CL0_baseline * (u0_baseline/u0_new)^2
```

7. Synchronize lateral lift-coefficient aliases, including `CL0` and `CL` where present.
8. Recompute Mach-derived speed derivatives when source fields exist:

```text
C_Lu  = M*CL_M
C_Du  = M*CD_M
C_m_u = M*Cm_M
```

### C.4 Implemented `u_0` validation status

The `u_0` workflow was checked on both NAVION and B747.

At the baseline sweep point, the parametric runner reproduced the normal `run_combined_AVS_analysis_FINAL.m` eigenvalues exactly for both:

```text
longitudinal branch
lateral/directional branch
```

This means the implemented `u_0` workflow preserves the validated baseline analysis path.

### C.5 Implemented `x_cg / cg_mac` policy

The implemented `x_cg` sweep uses the normalized center-of-gravity position:

```text
cg_mac = x_cg/c_bar
```

Default sweep range:

```text
baseline cg_mac ± 0.20
```

Safety limits:

```text
0.05 <= cg_mac <= 0.60
```

The current `x_cg` workflow is longitudinal only. Lateral/reference `x_cg` and `cg_mac` aliases are synchronized for consistency, but the lateral/directional branch is not rerun by default.

The tail-arm policy preserves the baseline horizontal-tail reference station:

```text
x_tail_ref = x_cg_baseline + lt_baseline
lt_new     = x_tail_ref - x_cg_new
```

The horizontal-tail volume ratio is recomputed from the updated `lt`:

```text
V_H = lt*St/(S*c_bar)
```

The `Cm_alpha` update is baseline preserving. The helper starts from the validated baseline direct `Cm_alpha` value and applies the incremental change caused by the new CG position and changed horizontal-tail volume.

Static stability is tracked using two methods:

```text
Primary method:   Cm_alpha / dCm_dCL
Secondary method: neutral-point static margin
```

If the two methods disagree, both are shown and the disagreement is flagged. The primary method is explicitly identified in the summary table and static-stability metadata.

Critical CG estimates are interpolated when a zero crossing exists inside the accepted sweep range.

### C.6 Implemented `x_cg` validation status

The `x_cg` helper and sweep workflow were checked on both NAVION and B747.

For NAVION, the sweep shows both static-method disagreement in the aft-CG region and a primary critical-CG crossing inside the accepted sweep range. For B747, the accepted sweep range remains stable by both static-stability methods.

---

## D. Parameter Map Table

| Parameter | Family | Branch | Sweepable | Policy needed | Priority | Risk | Status |
|---|---|---|---:|---:|---:|---:|---|
| `u_0` | Flight condition | Both | Yes | No | 1 | Low | Implemented |
| `rho` | Flight condition | Both | Yes | No | 1 | Low | Planned |
| `x_cg` | Longitudinal stability | Longitudinal | Yes | Yes | 1 | Medium | Implemented |
| `x_ac` | Longitudinal geometry | Longitudinal | Yes | No | 2 | Low | Planned |
| `CL0` | Aerodynamic input | Both | Yes | No | 2 | Medium | Planned |
| `CL_alpha` | Aerodynamic input | Longitudinal | Yes | No | 1 | Low | Planned |
| `C_Dalpha` | Aerodynamic input | Longitudinal | Yes | No | 2 | Low | Planned |
| `CD0` | Aerodynamic input | Longitudinal | Yes | No | 2 | Low | Planned |
| `eta` | Tail efficiency | Longitudinal | Yes | No | 1 | Low | Planned |
| `St` | Horizontal-tail geometry | Longitudinal | Yes | Yes | 1 | Medium | Planned |
| `lt` | Horizontal-tail geometry | Longitudinal | Yes | No | 1 | Low | Planned |
| `S` | Wing geometry | Both | Yes | Yes | 2 | Medium | Planned |
| `b` | Wing geometry | Lateral/directional | Yes | Yes | 2 | Medium | Planned |
| `c_bar` | Wing geometry | Longitudinal | Yes | Yes | 2 | Medium | Planned |
| `AR` | Wing geometry | Lateral/directional | Yes | Yes | 2 | Medium | Planned |
| `Sv` | Vertical-tail geometry | Lateral/directional | Yes | Yes | 1 | Medium | Planned |
| `lv` | Vertical-tail geometry | Lateral/directional | Yes | No | 1 | Low | Planned |
| `bv` | Vertical-tail geometry | Lateral/directional | Yes | Yes | 3 | Medium | Planned |
| `Gamma_w` | Wing geometry | Lateral/directional | Yes | No | 2 | Low | Planned |
| `sweep_w` | Wing geometry | Lateral/directional | Yes | No | 2 | Low | Planned |
| `TaperRatio` | Wing geometry | Lateral/directional | Yes | Yes | 3 | Medium | Planned |
| `m` | Mass | Both | Yes | No | 2 | Low | Planned |
| `Ix` | Inertia | Lateral/directional | Yes | No | 2 | Low | Planned |
| `Iy` | Inertia | Longitudinal | Yes | No | 2 | Low | Planned |
| `Iz` | Inertia | Lateral/directional | Yes | No | 2 | Low | Planned |
| `Ixz` | Inertia | Lateral/directional | Yes | No | 3 | Medium | Planned |

---

## E. Implemented First Parameter: `u_0`

### E.1 Reason for choosing `u_0`

`u_0` was selected as the first implemented parameter because:

```text
u_0 has a clear physical interpretation as the trim/reference flight speed.
u_0 affects dynamic pressure.
u_0 affects dimensional force and moment derivatives.
u_0 affects velocity-dependent terms in the A matrices.
u_0 affects both longitudinal and lateral/directional dynamic behavior.
u_0 is useful for validating the full chain from flight-condition variation to stability change.
```

### E.2 Expected chain

```text
u_0 changes
-> dynamic pressure changes
-> CL0 changes through baseline-preserving trim scaling
-> Mach number changes
-> Mach-derived speed derivatives may change
-> dimensional force and moment derivatives change
-> A/B matrix velocity terms change
-> longitudinal eigenvalues change
-> lateral/directional eigenvalues change
-> modal frequencies and damping ratios change
-> stability-envelope metrics change
```

### E.3 Primary tracked outputs

```text
u_0
Mach
qbar
CL0
existing dimensional derivatives
A_long
A_lat
B_long
B_lat
longitudinal eigenvalues
lateral/directional eigenvalues
short-period metrics
phugoid metrics
roll-mode metric
spiral-mode metric
Dutch-roll metrics
max real longitudinal eigenvalue
max real lateral eigenvalue
stability flags
warnings
```

### E.4 Output plots

The implemented `u_0` workflow generates:

```text
u_0_CL0_qbar.png
u_0_stability_envelope.png
u_0_longitudinal_eigenvalues.png
u_0_lateral_eigenvalues.png
u_0_A_long_sensitivity.png
u_0_A_lat_sensitivity.png
```

The A-matrix sensitivity heatmaps display the maximum absolute percent change from the baseline matrix entry over the sweep. `NaN` means the percent change is undefined, usually because the baseline matrix entry is zero.

---

## F. Implemented Second Parameter: `x_cg / cg_mac`

### F.1 Reason for implementing `x_cg`

`x_cg` was implemented as the second parameter because:

```text
x_cg has a clear physical interpretation.
x_cg strongly affects longitudinal static stability.
x_cg mainly affects the longitudinal branch.
x_cg is useful for validating the chain from center-of-gravity location to static margin, Cm_alpha, A-matrix behavior, and longitudinal eigenvalues.
```

The user-facing sweep variable is:

```text
cg_mac = x_cg/c_bar
```

### F.2 Expected chain

```text
cg_mac changes
-> x_cg changes
-> horizontal-tail arm lt changes under the fixed tail-reference-station policy
-> V_H changes
-> Cm_alpha changes through a baseline-preserving incremental update
-> dCm/dCL changes
-> static-stability margins change
-> A_long changes
-> longitudinal eigenvalues change
-> short-period and phugoid behavior changes
-> max real longitudinal eigenvalue changes
-> longitudinal stability classification may change
```

### F.3 Primary tracked outputs

```text
cg_mac
x_cg_ft
lt_ft
V_H
Cm_alpha
dCm_dCL
StaticMargin_CmAlpha
StaticMargin_NP
StaticStability_Primary
StaticStability_PrimaryMethod
StaticStability_Secondary_NP
StaticStability_MethodAgreement
critical CG estimates
A_long
B_long
longitudinal eigenvalues
max real longitudinal eigenvalue
longitudinal dynamic-stability flag
warnings
```

### F.4 Static-stability policy

The primary static-stability method is:

```text
Cm_alpha / dCm_dCL
```

The secondary method is:

```text
neutral-point static margin
```

Disagreements are flagged and retained in the output instead of being hidden.

### F.5 Output plots

The implemented `x_cg` workflow generates:

```text
x_cg_static_stability_envelope.png
x_cg_Cm_alpha_dCm_dCL.png
x_cg_stability_envelope.png
x_cg_longitudinal_eigenvalues.png
x_cg_A_long_sensitivity.png
```

The `x_cg` workflow intentionally does not generate `CL0/qbar` plots or lateral/directional plots, because the current `x_cg` implementation is longitudinal only.

Risk level:

```text
Medium
```

---

## G. Geometry Policies

### G.1 `S` policy

If `S` is swept:

```text
hold b fixed unless otherwise specified
hold c_bar fixed unless otherwise specified
recompute AR = b^2/S
```

### G.2 `b` policy

If `b` is swept:

```text
hold S fixed unless otherwise specified
recompute AR = b^2/S
```

### G.3 `c_bar` policy

If `c_bar` is swept:

```text
hold S fixed unless otherwise specified
hold b fixed unless otherwise specified
recompute only quantities that explicitly depend on c_bar
```

### G.4 `AR` policy

If `AR` is swept, define whether `S` or `b` is held fixed before implementation.

Recommended first `AR` policy:

```text
hold S fixed
recompute b = sqrt(AR*S)
```

Alternative `AR` policy:

```text
hold b fixed
recompute S = b^2/AR
```

The selected policy must be stated before `AR` is used in a sweep.

### G.5 `Sv` policy

If `Sv` is swept:

```text
hold bv fixed unless otherwise specified
recompute AR_v = bv^2/Sv if AR_v is used
```

### G.6 `bv` policy

If `bv` is swept:

```text
hold Sv fixed unless otherwise specified
recompute AR_v = bv^2/Sv if AR_v is used
```

### G.7 `St` policy

If `St` is swept:

```text
hold selected horizontal-tail reference dimensions fixed unless otherwise specified
recompute AR_t if the required geometry is available
```

### G.8 `TaperRatio` policy

If `TaperRatio` is swept:

```text
keep the selected wing reference area and span policy fixed
recompute any correction factors or interpolated quantities that depend on taper ratio
```
