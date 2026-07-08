# Unit Systems and Output Structure

This project uses aircraft-case input scripts written in AVS / Imperial-style aircraft units, while some analysis cores operate internally in SI units.

The combined runner preserves the existing validated analysis paths and adds standardized SI/AVS reporting containers around them.

## Native analysis paths

The current native analysis paths are:

| Branch                | Native core                          | Native output unit system |
| --------------------- | ------------------------------------ | ------------------------- |
| Longitudinal          | `SI_longitudinal_analysis_grouped.m` | SI                        |
| Lateral / directional | `AVS_lateral_directional_analysis.m` | AVS                       |

The unit-system expansion does not replace these analysis cores. It adds converted input and output snapshots for reporting, inspection, and workbook export.

## Standardized input containers

The combined runner creates these input containers:

```matlab
out.inputs_AVS
out.inputs_SI
```

Their main branches are:

```matlab
out.inputs_AVS.longitudinal
out.inputs_AVS.lateral_directional

out.inputs_SI.longitudinal
out.inputs_SI.lateral_directional
```

The AVS containers preserve the aircraft-case input quantities. The SI containers provide converted snapshots. The longitudinal SI input is the one used by the SI longitudinal core. The lateral SI input is a reporting/export snapshot.

The legacy input container is still retained:

```matlab
out.inputs
```

## Standardized output containers

The combined runner creates four standardized output containers:

```matlab
out.longitudinal_outputs_SI
out.longitudinal_outputs_AVS
out.lateral_outputs_AVS
out.lateral_outputs_SI
```

Their meaning is:

| Field                          | Unit system | Meaning                                             |
| ------------------------------ | ----------- | --------------------------------------------------- |
| `out.longitudinal_outputs_SI`  | SI          | Native output from the SI longitudinal core         |
| `out.longitudinal_outputs_AVS` | AVS         | Converted longitudinal output snapshot              |
| `out.lateral_outputs_AVS`      | AVS         | Native output from the AVS lateral/directional core |
| `out.lateral_outputs_SI`       | SI          | Converted lateral/directional output snapshot       |

The legacy output fields are still retained:

```matlab
out.longitudinal
out.lateral_directional
```

At this stage, they contain the same native outputs as:

```matlab
out.longitudinal_outputs_SI
out.lateral_outputs_AVS
```

## Workbook export sheets

When the combined runner exports `combined_stability_outputs.xlsx`, the main SI/AVS sheets are:

| Sheet                     | Meaning                                       |
| ------------------------- | --------------------------------------------- |
| `Unit_System_Guide`       | Human-readable guide to the SI/AVS containers |
| `Inputs_AVS`              | Flattened `out.inputs_AVS`                    |
| `Inputs_SI`               | Flattened `out.inputs_SI`                     |
| `Longitudinal_Output_SI`  | Flattened `out.longitudinal_outputs_SI`       |
| `Longitudinal_Output_AVS` | Flattened `out.longitudinal_outputs_AVS`      |
| `Lateral_Output_AVS`      | Flattened `out.lateral_outputs_AVS`           |
| `Lateral_Output_SI`       | Flattened `out.lateral_outputs_SI`            |

The older workbook sheets are still exported for compatibility.

## Conversion scope

The converted SI/AVS output snapshots are for reporting and export. They do not feed back into the analysis cores.

The conversion helpers preserve these quantities unchanged:

* Dimensionless aerodynamic coefficients
* Eigenvalues
* Damping ratios
* Natural frequencies
* Time constants
* Other seconds-based modal quantities

Dimensional quantities are converted only when their units are clear from the field name, structure location, or established analysis convention.

## Longitudinal output conversion

The longitudinal native output is SI. The helper:

```matlab
longitudinal_output_SI_to_AVS_snapshot.m
```

creates the AVS snapshot.

The longitudinal state-space conversion uses state scaling for:

```matlab
x_SI  = [Delta_u_mps;  Delta_w_mps;  Delta_q_radps; Delta_theta_rad]
x_AVS = [Delta_u_ftps; Delta_w_ftps; Delta_q_radps; Delta_theta_rad]
```

The longitudinal `A` matrix is converted by:

```matlab
A_AVS = T * A_SI / T
```

The longitudinal `B` matrix is converted by:

```matlab
B_AVS = T * B_SI
```

because the current longitudinal control inputs are angular or dimensionless.

## Lateral / directional output conversion

The lateral/directional native output is AVS. The helper:

```matlab
lateral_output_AVS_to_SI_snapshot.m
```

creates the SI snapshot.

The beta-based lateral state-space matrices are copied unchanged because the states and controls are:

```matlab
x = [beta; p; r; phi]
u = [delta_a; delta_r]
```

These are angular or seconds-based quantities. Dimensional flight-condition, geometry, force, moment, mass, and inertia quantities are converted when their units are unambiguous.

## Sign-convention note

The unit-system expansion does not change aerodynamic sign conventions.

Control-derivative and stability-derivative signs remain governed by the existing validated NAVION/B747 implementation and the current analysis-core conventions.
