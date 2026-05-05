---
applyTo: "modules/local/variant_callers.nf"
---

# Variant Callers Module Instructions

## Scope

These rules apply when editing [modules/local/variant_callers.nf](../../modules/local/variant_callers.nf).

## Contract and Wiring Rules

- Preserve nf-core style tuple/meta contracts expected by [workflows/hapfun.nf](../../workflows/hapfun.nf).
- Do not change emit names or output file types unless all downstream consumers are updated in the same change.
- Keep process-level edits minimal and avoid refactoring unrelated caller processes.

## Groovy and Shell Safety Rules

For triple-quoted Groovy script blocks:

- Escape shell variables meant for runtime using `\${...}`.
- Use default expansion for possibly unset vars under strict shell mode, for example `\${LD_PRELOAD:-}`.
- Avoid Groovy-fragile regex escapes like `\<...\>` where possible; use portable alternatives such as `grep -w`.
- Recheck shell quoting whenever building command strings via Groovy interpolation.

## GLNexus Rules

- Keep GLNexus behavior aligned with the guard in [workflows/hapfun.nf](../../workflows/hapfun.nf) that rejects `--caller freebayes` with `--gvcf_joint_caller glnexus`.
- Validate the GLNexus container tag is pullable before updating it.
- Verify required executables are available in the selected container; do not assume `bgzip` or `bcftools` exist in GLNexus images.
- Prefer producing BCF directly when container tool availability makes conversion steps fragile.

## Validation Checklist for Changes

- Confirm process scripts compile under Groovy (no invalid escapes).
- Confirm shell commands remain nounset-safe.
- Confirm caller outputs remain compatible with downstream VCF/BCF tools.
- Confirm README and parameter docs stay accurate when behavior changes.
