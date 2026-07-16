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

### C.1 Implemented parameter

The first implemented parametric-analysis variable is:

```text
u_0
```

The implementation consists of:

```text
build_u0_sweep_values.m
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

### C.2 Implemented output path

For each selected aircraft, the current `u_0` parametric-analysis output is saved under:

```text
results\<AIRCRAFT_CASE>\Parametric\u_0\
```

The output folder contains:

```text
u_0_parametric_summary.xlsx
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

---

## D. Parameter Map Table

| Parameter | Family | Branch | Sweepable | Policy needed | Priority | Risk | Status |
|---|---|---|---:|---:|---:|---:|---|
| `u_0` | Flight condition | Both | Yes | No | 1 | Low | Implemented |
| `rho` | Flight condition | Both | Yes | No | 1 | Low | Planned |
| `x_cg` | Longitudinal stability | Longitudinal | Yes | No | 1 | Low | Planned |
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

## F. Alternative First Parameter / Next Candidate: `x_cg`

The next likely parameter is:

```text
x_cg
```

Reason:

```text
x_cg has a clear physical interpretation.
x_cg strongly affects static margin.
x_cg mainly affects the longitudinal branch.
x_cg is useful for validating the longitudinal chain from center-of-gravity location to static and dynamic stability.
```

Expected chain:

```text
x_cg changes
-> moment arms change
-> static margin changes
-> Cm_alpha changes
-> A_long changes
-> longitudinal eigenvalues change
-> short-period and phugoid metrics change
-> longitudinal stability margin changes
```

Primary tracked outputs:

```text
static margin
x_NP
Cm_alpha
trim elevator angle
A_long
longitudinal eigenvalues
short-period damping ratio
phugoid damping ratio
max real longitudinal eigenvalue
longitudinal stability flag
```

Risk level:

```text
Low
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
