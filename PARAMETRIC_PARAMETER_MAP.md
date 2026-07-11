# Parametric Parameter Map

## A. Purpose

This document defines which aircraft inputs are available for parametric analysis, how each input is varied, what dependent quantities must be recomputed, and which outputs should be tracked.

This file supports the workflow defined in:

```text
PARAMETRIC_ANALYSIS_WORKFLOW.pdf
```

The parameter map must be defined before generalized parametric-analysis code is written.

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

## C. Parameter Map Table

| Parameter | Family | Branch | Sweepable | Policy needed | Priority | Risk |
|---|---|---|---:|---:|---:|---:|
| `u_0` | Flight condition | Both | Yes | No | 1 | Low |
| `rho` | Flight condition | Both | Yes | No | 1 | Low |
| `x_cg` | Longitudinal stability | Longitudinal | Yes | No | 1 | Low |
| `x_ac` | Longitudinal geometry | Longitudinal | Yes | No | 2 | Low |
| `CL0` | Aerodynamic input | Both | Yes | No | 2 | Medium |
| `CL_alpha` | Aerodynamic input | Longitudinal | Yes | No | 1 | Low |
| `C_Dalpha` | Aerodynamic input | Longitudinal | Yes | No | 2 | Low |
| `CD0` | Aerodynamic input | Longitudinal | Yes | No | 2 | Low |
| `eta` | Tail efficiency | Longitudinal | Yes | No | 1 | Low |
| `St` | Horizontal-tail geometry | Longitudinal | Yes | Yes | 1 | Medium |
| `lt` | Horizontal-tail geometry | Longitudinal | Yes | No | 1 | Low |
| `S` | Wing geometry | Both | Yes | Yes | 2 | Medium |
| `b` | Wing geometry | Lateral/directional | Yes | Yes | 2 | Medium |
| `c_bar` | Wing geometry | Longitudinal | Yes | Yes | 2 | Medium |
| `AR` | Wing geometry | Lateral/directional | Yes | Yes | 2 | Medium |
| `Sv` | Vertical-tail geometry | Lateral/directional | Yes | Yes | 1 | Medium |
| `lv` | Vertical-tail geometry | Lateral/directional | Yes | No | 1 | Low |
| `bv` | Vertical-tail geometry | Lateral/directional | Yes | Yes | 3 | Medium |
| `Gamma_w` | Wing geometry | Lateral/directional | Yes | No | 2 | Low |
| `sweep_w` | Wing geometry | Lateral/directional | Yes | No | 2 | Low |
| `TaperRatio` | Wing geometry | Lateral/directional | Yes | Yes | 3 | Medium |
| `m` | Mass | Both | Yes | No | 2 | Low |
| `Ix` | Inertia | Lateral/directional | Yes | No | 2 | Low |
| `Iy` | Inertia | Longitudinal | Yes | No | 2 | Low |
| `Iz` | Inertia | Lateral/directional | Yes | No | 2 | Low |
| `Ixz` | Inertia | Lateral/directional | Yes | No | 3 | Medium |

---

## D. First Implementation Candidate

### D.1 Recommended first parameter

Recommended first parameter:

```text
u_0
```

Reason:

```text
u_0 has a clear physical interpretation as the trim/reference flight speed.
u_0 affects dynamic pressure.
u_0 affects dimensional force and moment derivatives.
u_0 affects velocity-dependent terms in the A matrices.
u_0 affects both longitudinal and lateral/directional dynamic behavior.
u_0 is useful for validating the full chain from flight condition variation to stability change.
```

Expected chain:

```text
u_0 changes
-> dynamic pressure changes
-> dimensional force and moment derivatives change
-> A/B matrix velocity terms change
-> longitudinal eigenvalues change
-> lateral/directional eigenvalues change
-> modal frequencies and damping ratios change
-> stability-envelope metrics change
```

Primary tracked outputs:

```text
qbar
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
```

Risk level:

```text
Low to medium
```

Implementation note:

```text
u_0 is broader than x_cg because it affects both longitudinal and lateral/directional branches. This makes it a stronger first test of the general parametric-analysis backend, but it also means validation must check both branches.
```

### D.2 Alternative first parameter

Alternative first parameter:

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

## E. Geometry Policies

### E.1 `S` policy

If `S` is swept:

```text
hold b fixed unless otherwise specified
hold c_bar fixed unless otherwise specified
recompute AR = b^2/S
```

### E.2 `b` policy

If `b` is swept:

```text
hold S fixed unless otherwise specified
recompute AR = b^2/S
```

### E.3 `c_bar` policy

If `c_bar` is swept:

```text
hold S fixed unless otherwise specified
hold b fixed unless otherwise specified
recompute only quantities that explicitly depend on c_bar
```

### E.4 `AR` policy

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

### E.5 `Sv` policy

If `Sv` is swept:

```text
hold bv fixed unless otherwise specified
recompute AR_v = bv^2/Sv if AR_v is used
```

### E.6 `bv` policy

If `bv` is swept:

```text
hold Sv fixed unless otherwise specified
recompute AR_v = bv^2/Sv if AR_v is used
```

### E.7 `St` policy

If `St` is swept:

```text
hold selected horizontal-tail reference dimensions fixed unless otherwise specified
recompute AR_t if the required geometry is available
```

### E.8 `TaperRatio` policy

If `TaperRatio` is swept:

```text
keep the selected wing reference area and span policy fixed
recompute any correction factors or interpolated quantities that depend on taper ratio
```

---
