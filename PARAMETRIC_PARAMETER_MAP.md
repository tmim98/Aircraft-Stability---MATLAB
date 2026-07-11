\# Parametric Parameter Map



\## A. Purpose



This document defines which aircraft inputs are available for parametric analysis, how each input is varied, what dependent quantities must be recomputed, and which outputs should be tracked.



This file supports the workflow defined in:



&#x20;   PARAMETRIC\_ANALYSIS\_WORKFLOW.pdf



The parameter map must be defined before generalized parametric-analysis code is written.



\---



\## B. Parameter Classification Rules



\### B.1 Canonical names



Duplicate names should be avoided.



Use:



&#x20;   x\_cg instead of cg

&#x20;   x\_ac instead of ac

&#x20;   m instead of W, unless W is deliberately chosen as the primary input



\### B.2 Sweepable parameter



A sweepable parameter is an input that can be varied over a chosen range while the analysis is rerun at each value.



Example:



&#x20;   x\_cg baseline value: 0.75 m



&#x20;   sweep values:

&#x20;       0.65

&#x20;       0.70

&#x20;       0.75

&#x20;       0.80

&#x20;       0.85



For each value, the code updates the selected parameter, reruns the analysis, and stores the resulting derivatives, matrices, eigenvalues, mode metrics, and stability flags.



\### B.3 Hold-fixed/recompute policy



Geometry-related parameters must define which quantities remain fixed and which quantities are recomputed.



Example:



&#x20;   if S changes:

&#x20;       hold b fixed unless otherwise specified

&#x20;       hold c\_bar fixed unless otherwise specified

&#x20;       recompute AR = b^2/S



This prevents geometry-sensitive parameters from being varied blindly.



\---



\## C. Parameter Map Table



| Parameter | Family | Branch | Sweepable | Policy needed | Priority | Risk |

|---|---|---|---:|---:|---:|---:|

| u\_0 | Flight condition | Both | Yes | No | 1 | Low |

| rho | Flight condition | Both | Yes | No | 1 | Low |

| x\_cg | Longitudinal stability | Longitudinal | Yes | No | 1 | Low |

| x\_ac | Longitudinal geometry | Longitudinal | Yes | No | 2 | Low |

| CL0 | Aerodynamic input | Both | Yes | No | 2 | Medium |

| CL\_alpha | Aerodynamic input | Longitudinal | Yes | No | 1 | Low |

| C\_Dalpha | Aerodynamic input | Longitudinal | Yes | No | 2 | Low |

| CD0 | Aerodynamic input | Longitudinal | Yes | No | 2 | Low |

| eta | Tail efficiency | Longitudinal | Yes | No | 1 | Low |

| St | Horizontal-tail geometry | Longitudinal | Yes | Yes | 1 | Medium |

| lt | Horizontal-tail geometry | Longitudinal | Yes | No | 1 | Low |

| S | Wing geometry | Both | Yes | Yes | 2 | Medium |

| b | Wing geometry | Lateral/directional | Yes | Yes | 2 | Medium |

| c\_bar | Wing geometry | Longitudinal | Yes | Yes | 2 | Medium |

| AR | Wing geometry | Lateral/directional | Yes | Yes | 2 | Medium |

| Sv | Vertical-tail geometry | Lateral/directional | Yes | Yes | 1 | Medium |

| lv | Vertical-tail geometry | Lateral/directional | Yes | No | 1 | Low |

| bv | Vertical-tail geometry | Lateral/directional | Yes | Yes | 3 | Medium |

| Gamma\_w | Wing geometry | Lateral/directional | Yes | No | 2 | Low |

| sweep\_w | Wing geometry | Lateral/directional | Yes | No | 2 | Low |

| TaperRatio | Wing geometry | Lateral/directional | Yes | Yes | 3 | Medium |

| m | Mass | Both | Yes | No | 2 | Low |

| Ix | Inertia | Lateral/directional | Yes | No | 2 | Low |

| Iy | Inertia | Longitudinal | Yes | No | 2 | Low |

| Iz | Inertia | Lateral/directional | Yes | No | 2 | Low |

| Ixz | Inertia | Lateral/directional | Yes | No | 3 | Medium |



\---

\## D. First Implementation Candidate



\### D.1 Recommended first parameter



Recommended first parameter:



&#x20;   u\_0



Reason:



&#x20;   u\_0 has a clear physical interpretation as the trim/reference flight speed.

&#x20;   u\_0 affects dynamic pressure.

&#x20;   u\_0 affects dimensional force and moment derivatives.

&#x20;   u\_0 affects velocity-dependent terms in the A matrices.

&#x20;   u\_0 affects both longitudinal and lateral/directional dynamic behavior.

&#x20;   u\_0 is useful for validating the full chain from flight condition variation to stability change.



Expected chain:



&#x20;   u\_0 changes

&#x20;   -> dynamic pressure changes

&#x20;   -> dimensional force and moment derivatives change

&#x20;   -> A/B matrix velocity terms change

&#x20;   -> longitudinal eigenvalues change

&#x20;   -> lateral/directional eigenvalues change

&#x20;   -> modal frequencies and damping ratios change

&#x20;   -> stability-envelope metrics change



Primary tracked outputs:



&#x20;   qbar

&#x20;   existing dimensional derivatives

&#x20;   A\_long

&#x20;   A\_lat

&#x20;   B\_long

&#x20;   B\_lat

&#x20;   longitudinal eigenvalues

&#x20;   lateral/directional eigenvalues

&#x20;   short-period metrics

&#x20;   phugoid metrics

&#x20;   roll-mode metric

&#x20;   spiral-mode metric

&#x20;   Dutch-roll metrics

&#x20;   max real longitudinal eigenvalue

&#x20;   max real lateral eigenvalue

&#x20;   stability flags



Risk level:



&#x20;   Low to medium



Implementation note:



&#x20;   u\_0 is broader than x\_cg because it affects both longitudinal and lateral/directional branches. This makes it a stronger first test of the general parametric-analysis backend, but it also means validation must check both branches.



\### D.2 Alternative first parameter



Alternative first parameter:



&#x20;   x\_cg



Reason:



&#x20;   x\_cg has a clear physical interpretation.

&#x20;   x\_cg strongly affects static margin.

&#x20;   x\_cg mainly affects the longitudinal branch.

&#x20;   x\_cg is useful for validating the longitudinal chain from center-of-gravity location to static and dynamic stability.



Expected chain:



&#x20;   x\_cg changes

&#x20;   -> moment arms change

&#x20;   -> static margin changes

&#x20;   -> Cm\_alpha changes

&#x20;   -> A\_long changes

&#x20;   -> longitudinal eigenvalues change

&#x20;   -> short-period and phugoid metrics change

&#x20;   -> longitudinal stability margin changes



Primary tracked outputs:



&#x20;   static margin

&#x20;   x\_NP

&#x20;   Cm\_alpha

&#x20;   trim elevator angle

&#x20;   A\_long

&#x20;   longitudinal eigenvalues

&#x20;   short-period damping ratio

&#x20;   phugoid damping ratio

&#x20;   max real longitudinal eigenvalue

&#x20;   longitudinal stability flag



Risk level:



&#x20;   Low

\---



\## E. Geometry Policies



\### E.1 S policy



If S is swept:



&#x20;   hold b fixed unless otherwise specified

&#x20;   hold c\_bar fixed unless otherwise specified

&#x20;   recompute AR = b^2/S



\### E.2 b policy



If b is swept:



&#x20;   hold S fixed unless otherwise specified

&#x20;   recompute AR = b^2/S



\### E.3 c\_bar policy



If c\_bar is swept:



&#x20;   hold S fixed unless otherwise specified

&#x20;   hold b fixed unless otherwise specified

&#x20;   recompute only quantities that explicitly depend on c\_bar



\### E.4 AR policy



If AR is swept:



&#x20;   define whether S or b is held fixed before implementation



Recommended first AR policy:



&#x20;   hold S fixed

&#x20;   recompute b = sqrt(AR\*S)



Alternative AR policy:



&#x20;   hold b fixed

&#x20;   recompute S = b^2/AR



The selected policy must be stated before AR is used in a sweep.



\### E.5 Sv policy



If Sv is swept:



&#x20;   hold bv fixed unless otherwise specified

&#x20;   recompute AR\_v = bv^2/Sv if AR\_v is used



\### E.6 bv policy



If bv is swept:



&#x20;   hold Sv fixed unless otherwise specified

&#x20;   recompute AR\_v = bv^2/Sv if AR\_v is used



\### E.7 St policy



If St is swept:



&#x20;   hold selected horizontal-tail reference dimensions fixed unless otherwise specified

&#x20;   recompute AR\_t if the required geometry is available



\### E.8 TaperRatio policy



If TaperRatio is swept:



&#x20;   keep the selected wing reference area and span policy fixed

&#x20;   recompute any correction factors or interpolated quantities that depend on taper ratio



\---



\## F. Tracked Output Rule



The first parametric-analysis implementation should track only quantities that are already produced by the validated analysis code.



Do not introduce new derivative names during the first version unless they are already calculated by the existing output structures.



Example:



&#x20;   Do not track X\_alpha unless the current longitudinal output struct already contains it.



The first version should prioritize:



&#x20;   static margin

&#x20;   trim quantities

&#x20;   existing nondimensional derivatives

&#x20;   existing dimensional derivatives

&#x20;   A matrices

&#x20;   B matrices

&#x20;   eigenvalues

&#x20;   damping ratios

&#x20;   natural frequencies

&#x20;   max real eigenvalue

&#x20;   stability flags

&#x20;   warnings

