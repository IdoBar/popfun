# PopFun Copilot Instructions

## Project Overview

PopFun is a Nextflow DSL2 pipeline for population-scale fungal variant discovery with optional population genetics and error-estimation branches.

This file is the global guidance layer. Module-specific rules live under `.github/instructions/`.

Start here:
- [README.md](../README.md)
- [nextflow.config](../nextflow.config)
- [workflows/popfun.nf](../workflows/popfun.nf)
- [conf/base.config](../conf/base.config)

## Core Development Rules

- Keep workflow logic in DSL2 style with explicit module includes and channel wiring as shown in [workflows/popfun.nf](../workflows/popfun.nf).
- Preserve nf-core style metadata tuples and maps (`meta` maps and tuple contracts) across module boundaries.
- Do not change emitted channel shapes unless every consumer is updated in the same change.
- Prefer minimal, targeted edits and simple code solutions that relies minimally on loops utilising internal variables; avoid broad refactors in this repository.

## Scoped Instruction Files

- Use [instructions/variant-callers.instructions.md](instructions/variant-callers.instructions.md) when editing [modules/local/variant_callers.nf](../modules/local/variant_callers.nf).

## Container and Tooling Validation

Before changing container tags or adding new tools to a process:

- Verify the image tag exists and is pullable from the target registry.
- Verify required executables actually exist in that container.
- Prefer official, stable images over opaque mulled tags unless there is a clear reproducibility reason.
- If a process relies on tools not present in the chosen image, either:
  - switch to a valid image that includes them, or
  - change the process output/flow to avoid those tools.

## Configuration and Profile Conventions

- Keep default params and profile overrides centralized in [nextflow.config](../nextflow.config).
- Test profile should use project-root-resolved paths for bundled test data.
- Resource policies and label semantics come from [conf/base.config](../conf/base.config); process-specific test downsizing belongs in `profiles.test.process.withName` overrides.

## Validation Expectations for Changes

For any pipeline logic change, validate at least:

- Parameter compatibility guards in [workflows/popfun.nf](../workflows/popfun.nf).
- Process input/output contract compatibility between module and workflow wiring.
- Container pullability and command availability for modified processes.
- README accuracy when behavior changes (especially caller and joint-caller combinations).

## Practical Lessons from Prior Fixes

- Many failures surfaced as secondary Nextflow exceptions after a process failed; always identify the first process error and exit code.
- Many failures resulted from improper escaping of variables and newlines (`\n`) in Nextflow `script` blocks processed by Groovy. Make sure to escape variables properly (use `\\n` for newlines within `awk` scripts) to avoid issues or use Nextflow `shell` blocks as an alternative.
- Relative samplesheet paths can resolve incorrectly if not anchored; workflow input resolution should check project-root and samplesheet-relative candidates.
- Always run Nextflow validation test runs on local `wsl` (may need an active login to activate the `base` conda environment where Nextflow is installed) and make sure to escape Windows paths and internal variables properly; prefer absolute paths and verify with `pwd` in the test profile.
