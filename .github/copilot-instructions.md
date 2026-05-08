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
- When adding new Nextflow processes, explicitly add them to the relevant `profiles.test.process.withName` block in [nextflow.config](../nextflow.config) instead of relying on an unrelated catch-all matcher.

## Validation Expectations for Changes

For any pipeline logic change, validate at least:

- Parameter compatibility guards in [workflows/popfun.nf](../workflows/popfun.nf).
- Process input/output contract compatibility between module and workflow wiring.
- Container pullability and command availability for modified processes.
- README accuracy when behavior changes (especially caller and joint-caller combinations).

## Practical Lessons from Prior Fixes

- Many failures surfaced as secondary Nextflow exceptions after a process failed; always identify the first process error and exit code.
- Many failures resulted from improper escaping of variables and string literals in Nextflow `script` blocks processed by Groovy. When writing `awk` inside triple-quoted Groovy strings, treat backslash escapes as Groovy-sensitive: use `\\n` for newlines, `\\t` for tabs, and `\\\"` for embedded double quotes that must survive into the runtime `awk` program. Do not assume `\n`, `\t`, or `\"` will reach `awk` unchanged.
- For `awk` programs embedded in Nextflow `script` blocks, prefer a quick literal-escaping review before finalizing edits: check every `FS`/`OFS`, `printf` format string, and emitted header line for Groovy-safe escaping.
- Relative samplesheet paths can resolve incorrectly if not anchored; workflow input resolution should check project-root and samplesheet-relative candidates.
- Always run Nextflow validation test runs on local `wsl`, where Nextflow is installed in the `base` conda environment. Before invoking Nextflow, activate that environment by sourcing `~/.bashrc` or by using an interactive/login shell session that loads the same startup configuration. Make sure to escape Windows paths and internal variables properly; prefer absolute paths and verify with `pwd` in the test profile.
