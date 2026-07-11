# Validation Workflow

This project uses small, batch-based changes. Each batch should be validated before it is committed, unless the batch is explicitly documentation-only or comment-only.

The main validation target is the combined workbook exported by:

&#x20;   run\_combined\_AVS\_analysis\_FINAL


The validation process compares the newly generated workbook against the previously approved workbook for the same aircraft case.

## Standard aircraft cases

For normal validation, run both supported aircraft cases:

&#x20;   NAVION
    B747


For each case, answer `Y` when the runner asks whether to export the combined workbook.

The expected workbook path is:

&#x20;   results/<AIRCRAFT\_CASE>/combined\_stability\_outputs.xlsx


For manual tracking during batch validation, copy or rename the exported files using names such as:

&#x20;   NAVION\_batch##\_combined\_stability\_outputs.xlsx
    B747\_batch##\_combined\_stability\_outputs.xlsx


## What should be compared

Compare the new workbook against the previous approved workbook for the same aircraft:

&#x20;   NAVION\_batch## versus NAVION\_previous\_batch
    B747\_batch## versus B747\_previous\_batch


The comparison should cover:

* Sheet names
* Sheet dimensions
* Cell-by-cell values
* Complex-value real and imaginary columns
* Text metadata where relevant

## Expected acceptable differences

The following differences are normally acceptable:

* Timestamp changes in the `Summary` sheet
* New sheets that were intentionally added by the current batch
* New metadata rows that were intentionally added by the current batch
* Comment-only or documentation-only changes causing no workbook changes

The following differences are not acceptable unless the batch explicitly intended them:

* Changes to eigenvalues
* Changes to dimensional derivatives
* Changes to nondimensional aerodynamic coefficients
* Changes to state-space matrices
* Changes to modal classifications
* Changes to static-stability values
* Disappearing sheets or missing fields
* Unexpected unit-conversion changes

## Numerical safety rule

Any batch that can affect calculations must be validated by comparing the newly generated workbook against the previous approved workbook.

For this project, a calculation-affecting batch includes changes to:

* Input conversion helpers
* Output conversion helpers
* Analysis-core code
* State-space matrix construction
* Stability derivatives
* Sign conventions
* Plot data generation if it touches computed modal data
* Workbook export code if it changes which data are written

## Low-risk batches

The following batches usually do not require a full NAVION/B747 rerun:

* Markdown documentation files
* Comment-only MATLAB edits
* README-only changes
* Header documentation updates

Even for low-risk batches, inspect the changed file before committing.

## GitHub commit rule

Only commit source/documentation files that belong in the repository.

Do not commit generated validation artifacts unless they are intentionally meant to be versioned.

Usually leave these unchecked in GitHub Desktop:

&#x20;   combined\_stability\_outputs.xlsx
    combined\_stability\_report.txt
    Mode\_Response\_Plots/
    results/


The preferred workflow is:

1. Make one small batch change.
2. Run the relevant validation.
3. Compare outputs.
4. Commit only after approval.
5. Push to GitHub.
6. Move to the next batch.

## Sign-convention rule

The unit-system expansion must not change aerodynamic sign conventions.

Control-derivative and stability-derivative signs remain governed by the existing validated NAVION/B747 implementation and the current analysis-core conventions.

