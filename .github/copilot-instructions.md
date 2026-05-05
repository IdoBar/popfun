# HapFun Copilot Instructions

## Project Overview

HapFun is a Nextflow DSL2 pipeline for haploid fungal variant discovery with optional population genetics and error-estimation branches.

This file is the global guidance layer. Module-specific rules live under `.github/instructions/`.

Start here:
- [README.md](../README.md)
- [nextflow.config](../nextflow.config)
- [workflows/hapfun.nf](../workflows/hapfun.nf)
- [conf/base.config](../conf/base.config)

## Core Development Rules

- Keep workflow logic in DSL2 style with explicit module includes and channel wiring as shown in [workflows/hapfun.nf](../workflows/hapfun.nf).
- Preserve nf-core style metadata tuples and maps (`meta` maps and tuple contracts) across module boundaries.
- Do not change emitted channel shapes unless every consumer is updated in the same change.
- Prefer minimal, targeted edits; avoid broad refactors in this repository.

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

- Parameter compatibility guards in [workflows/hapfun.nf](../workflows/hapfun.nf).
- Process input/output contract compatibility between module and workflow wiring.
- Container pullability and command availability for modified processes.
- README accuracy when behavior changes (especially caller and joint-caller combinations).

## Practical Lessons from Prior Fixes

- Many failures surfaced as secondary Nextflow exceptions after a process failed; always identify the first process error and exit code.
- Relative samplesheet paths can resolve incorrectly if not anchored; workflow input resolution should check project-root and samplesheet-relative candidates.
