# PopFun Development & Testing Instructions

## ⚠️ Important: Always Use a Scratch Folder for Nextflow Runs

**Do NOT run Nextflow processes in the main project folder.** Always use a dedicated scratch folder to avoid cluttering the repository with workflow artifacts.

### Why?

Nextflow generates numerous temporary and output files:
- `.nextflow/` — workflow cache directory
- `.nextflow.log` — execution logs
- `work/` — task execution directories (potentially hundreds of GB)
- Pipeline outputs (unless redirected to `--outdir`)

These artifacts can:
- Pollute version control and slow down git operations
- Fill disk space with unnecessary temporary files
- Make it difficult to distinguish code changes from generated files

### Setup Your Scratch Folder

**For WSL2 / Linux environments:**

```bash
# Create a scratch folder in a location with sufficient disk space
mkdir -p ~/scratch/popfun_work
cd ~/scratch/popfun_work

# Symlink the project so you can reference it from the scratch directory
ln -s /path/to/popfun project
```

**For Windows (PowerShell):**

```powershell
# Create a scratch folder (outside the project directory)
New-Item -ItemType Directory -Force -Path "C:\Temp\popfun_scratch"
cd C:\Temp\popfun_scratch

# Option 1: Use absolute path to project
# (references below)

# Option 2: Create symlink (requires admin)
New-Item -ItemType SymbolicLink -Path "project" -Target "C:\Users\idoid\Griffith University\...\popfun"
```

### Running Nextflow from Scratch Folder

Always change to the scratch directory **before** running Nextflow:

```bash
# Navigate to scratch folder
cd ~/scratch/popfun_work

# Run pipeline with absolute path to project
nextflow run /path/to/popfun/main.nf \
    -profile docker \
    --input /path/to/samplesheet.csv \
    --ref /path/to/reference.fa \
    --outdir results
```

**Or with profile + test mode:**

```bash
nextflow run /path/to/popfun/main.nf \
    -profile test,docker \
    --outdir results_test
```

### Expected Directory Structure in Scratch Folder

After running a pipeline, your scratch folder will contain:

```
~/scratch/popfun_work/
├── .nextflow/              # Workflow cache (safe to delete after run)
├── .nextflow.log           # Execution logs
├── work/                   # Task execution directories (LARGE - safe to delete)
└── results/                # Final outputs (keep these!)
```

### Cleanup After Successful Runs

After validating results, clean up temporary files:

```bash
# Remove Nextflow cache and work directories (keep results!)
rm -rf .nextflow work .nextflow.log

# Or keep results but move them elsewhere first
mv results ~/validated_results/
rm -rf .nextflow work .nextflow.log
```

**On Windows PowerShell:**

```powershell
# Remove directories
Remove-Item -Recurse -Force .nextflow, work
Remove-Item -Force .nextflow.log
```

---

## Development Workflow

### For Code Changes

1. **Make changes in the project folder** (e.g., `modules/local/variant_callers.nf`)
2. **Create a new scratch folder** for testing the changes
3. **Run test profile** from scratch folder to validate

```bash
# In scratch folder
cd ~/scratch/popfun_test_$(date +%s)
nextflow run /path/to/popfun/main.nf -profile test,docker
```

### For Module-Specific Changes

See [.github/instructions/](../.github/instructions/) for module-specific development guidelines:
- [variant-callers.instructions.md](./.github/instructions/variant-callers.instructions.md) — when editing variant calling modules

### For Documentation Changes

- Update [README.md](./README.md) for user-facing features
- Update [.github/copilot-instructions.md](./.github/copilot-instructions.md) for developer AI guidance
- Update this file (INSTRUCTIONS.md) for development & testing procedures

---

## Common Development Tasks

### Running a Quick Test

```bash
# Create temporary scratch folder
mkdir -p ~/scratch/popfun_quick_test
cd ~/scratch/popfun_quick_test

# Run test profile (uses bundled test data)
nextflow run /path/to/popfun/main.nf -profile test,docker -resume
```

### Testing with Custom Data

```bash
cd ~/scratch/popfun_custom_test

# Run with your samplesheet
nextflow run /path/to/popfun/main.nf \
    -profile docker \
    --input /path/to/samplesheet.csv \
    --ref /path/to/reference.fa \
    --outdir results \
    -resume  # Use cached results from previous runs
```

### Debugging a Failed Task

```bash
# After a run fails, examine the task directory
cd work/ab/cde1234567890abcdef1234567890/

# View stderr and stdout
cat .command.err  # Error messages
cat .command.out  # Standard output
cat .command.log  # Execution log

# The actual command:
cat .command.sh
```

### Validating Configuration Changes

Before running long pipelines, validate the configuration:

```bash
cd ~/scratch/popfun_work

# Syntax check
nextflow config /path/to/popfun/nextflow.config -validate

# View resolved config (with all interpolations)
nextflow config /path/to/popfun/nextflow.config
```

---

## Path Handling in Container Environments

**Important**: All Nextflow runs use Docker/containers. File paths with spaces must be properly quoted in all shell commands.

### Path Quoting Rules

✅ **Correct** (all critical paths quoted):
```groovy
script:
"""
gatk HaplotypeCaller -R "$ref" -I "$bam" -O "${meta.id}.vcf.gz"
"""
```

❌ **Incorrect** (unquoted paths fail with spaces):
```groovy
script:
"""
gatk HaplotypeCaller -R $ref -I $bam -O ${meta.id}.vcf.gz
"""
```

All Nextflow modules in this pipeline use proper quoting. Do not remove quotes when editing shell scripts.

---

## Repository Cleanup

To keep the repository clean, the following files should **never** be committed:

```
.nextflow/
.nextflow.log
work/
results/
.DS_Store
*.swp
*~
```

These are already in [.gitignore](./.gitignore).

---

## Additional Resources

- **Nextflow Documentation**: https://www.nextflow.io/docs/latest/index.html
- **nf-core Best Practices**: https://nf-co.re/docs/guidelines
- **PopFun README**: [README.md](./README.md) — user guide and parameter reference
- **PopFun Copilot Instructions**: [.github/copilot-instructions.md](./.github/copilot-instructions.md) — AI development guidance
