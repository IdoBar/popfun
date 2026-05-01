#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Download container images referenced by a Nextflow pipeline into a local cache.

Usage:
  download_nf_containers.sh --pipeline-dir <path> [--target-dir <path>] [--dry-run]

Behavior:
  1) Parses .nf and .config files for container declarations.
  2) Resolves target directory in this order:
     - --target-dir
     - $NXF_SINGULARITY_CACHEDIR
     - $NXF_APPTAINER_CACHEDIR
     - <pipeline-dir>/containers/cache
  3) Attempts download with aria2c, then wget, then curl.

Notes:
  - Supports direct HTTP/HTTPS container URLs as-is.
  - For docker-like image references (e.g. quay.io/biocontainers/fastqc:TAG),
    this script tries Galaxy's Singularity depot URL patterns.
  - If no candidate URL works, the image is reported as failed.

Options:
  -p, --pipeline-dir   Nextflow pipeline folder (required)
  -t, --target-dir     Destination directory for downloaded files
  -n, --dry-run        Print actions without downloading
  -h, --help           Show this help
EOF
}

log() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

err() {
    printf 'ERROR: %s\n' "$*" >&2
}

have_cmd() {
    command -v "$1" >/dev/null 2>&1
}

download_with_fallback() {
    # Args: url output_path dry_run
    local url="$1"
    local out="$2"
    local dry_run="$3"

    if [[ "$dry_run" == "1" ]]; then
        log "DRY-RUN download: $url -> $out"
        return 0
    fi

    mkdir -p "$(dirname "$out")"

    if have_cmd aria2c; then
        if aria2c --allow-overwrite=false --continue=true --max-connection-per-server=8 --split=8 --min-split-size=1M --retry-wait=3 --max-tries=5 --out "$(basename "$out")" --dir "$(dirname "$out")" "$url" >/dev/null 2>&1; then
            return 0
        fi
    fi

    if have_cmd wget; then
        if wget -q -c -O "$out" "$url"; then
            return 0
        fi
    fi

    if have_cmd curl; then
        if curl -fsSL --retry 5 --retry-delay 3 -o "$out" "$url"; then
            return 0
        fi
    fi

    return 1
}

extract_containers() {
    # Args: pipeline_dir
    local pdir="$1"

    find "$pdir" -type f \( -name '*.nf' -o -name '*.config' \) -print0 \
        | xargs -0 grep -nE "(^|[[:space:]])container([[:space:]]*=)?[[:space:]]*['\"][^'\"]+['\"]" 2>/dev/null \
        | sed -E "s/.*container([[:space:]]*=)?[[:space:]]*['\"]([^'\"]+)['\"].*/\2/" \
        | sed -E '/\$\{|^[[:space:]]*$/d' \
        | sort -u
}

sanitize_filename() {
    local s="$1"
    s="${s#docker://}"
    s="${s#oras://}"
    s="${s//\//_}"
    s="${s//:/_}"
    s="${s//@/_}"
    printf '%s' "$s"
}

candidate_urls_for_image() {
    # Args: image_ref
    local image="$1"

    # Direct URL is accepted as-is.
    if [[ "$image" =~ ^https?:// ]]; then
        printf '%s\n' "$image"
        return
    fi

    # Normalize common schemes.
    image="${image#docker://}"
    image="${image#oras://}"

    local path_part tag name
    if [[ "$image" == *:* ]]; then
        path_part="${image%%:*}"
        tag="${image##*:}"
    else
        path_part="$image"
        tag="latest"
    fi
    name="${path_part##*/}"

    # Most nf-core style biocontainers are mirrored here.
    printf 'https://depot.galaxyproject.org/singularity/%s:%s\n' "$name" "$tag"

    # Some mirrors keep full registry path with separators normalized.
    local full_norm
    full_norm="${image//\//_}"
    full_norm="${full_norm//:/_}"
    printf 'https://depot.galaxyproject.org/singularity/%s.sif\n' "$full_norm"
    printf 'https://depot.galaxyproject.org/singularity/%s.img\n' "$full_norm"
}

PIPELINE_DIR=""
TARGET_DIR=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--pipeline-dir)
            PIPELINE_DIR="${2:-}"
            shift 2
            ;;
        -t|--target-dir)
            TARGET_DIR="${2:-}"
            shift 2
            ;;
        -n|--dry-run)
            DRY_RUN=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            err "Unknown argument: $1"
            usage
            exit 1
            ;;
    esac
done

if [[ -z "$PIPELINE_DIR" ]]; then
    err "--pipeline-dir is required"
    usage
    exit 1
fi

if [[ ! -d "$PIPELINE_DIR" ]]; then
    err "Pipeline directory does not exist: $PIPELINE_DIR"
    exit 1
fi

if [[ -z "$TARGET_DIR" ]]; then
    if [[ -n "${NXF_SINGULARITY_CACHEDIR:-}" ]]; then
        TARGET_DIR="$NXF_SINGULARITY_CACHEDIR"
    elif [[ -n "${NXF_APPTAINER_CACHEDIR:-}" ]]; then
        TARGET_DIR="$NXF_APPTAINER_CACHEDIR"
    else
        TARGET_DIR="$PIPELINE_DIR/containers/cache"
    fi
fi

mkdir -p "$TARGET_DIR"

log "Scanning pipeline directory: $PIPELINE_DIR"
mapfile -t images < <(extract_containers "$PIPELINE_DIR")

if [[ ${#images[@]} -eq 0 ]]; then
    log "No container declarations were found."
    exit 0
fi

log "Found ${#images[@]} unique container references"
log "Target directory: $TARGET_DIR"

declare -a failed=()

for image in "${images[@]}"; do
    out_base="$(sanitize_filename "$image")"
    out_file="$TARGET_DIR/${out_base}.sif"

    # Keep existing file if already present.
    if [[ -s "$out_file" ]]; then
        log "Exists, skipping: $out_file"
        continue
    fi

    log "Resolving: $image"
    success=0
    while IFS= read -r url; do
        [[ -z "$url" ]] && continue
        log "Trying: $url"
        if download_with_fallback "$url" "$out_file" "$DRY_RUN"; then
            if [[ "$DRY_RUN" == "1" || -s "$out_file" ]]; then
                log "Downloaded: $out_file"
                success=1
                break
            fi
        fi
    done < <(candidate_urls_for_image "$image")

    if [[ $success -eq 0 ]]; then
        err "Could not download image: $image"
        failed+=("$image")
        rm -f "$out_file" 2>/dev/null || true
    fi
done

if [[ ${#failed[@]} -gt 0 ]]; then
    printf '\nFailed images (%d):\n' "${#failed[@]}" >&2
    printf '  %s\n' "${failed[@]}" >&2
    printf '\nTip: pull failed images with apptainer/singularity, e.g.\n' >&2
    printf '  apptainer pull --dir "%s" docker://<image>\n' "$TARGET_DIR" >&2
    exit 2
fi

log "All container downloads completed"
