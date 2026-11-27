#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"

readonly MARKER=".installed-by-semantic-web-reasoner-skill"

TARGET="all"
SCOPE="user"
PROJECT_DIR=""
OPENCODE_MODEL=""
CLAUDE_MODEL=""
RESOLVED_OPENCODE_MODEL=""
OPENCODE_MODEL_BRANCH=""
LINK_MODE=false
FORCE=false
WITH_AGENTS=false
UNINSTALL=false
DRY_RUN=false
VERBOSE=false

declare -a REQUESTED_SKILLS=()
declare -a DISCOVERED_SKILLS=()
declare -a SELECTED_SKILLS=()
declare -a TARGET_ROOTS=()

OPENCODE_SKILLS_ROOT=""
CLAUDE_SKILLS_ROOT=""
CLAUDE_AGENTS_DIR=""
CLAUDE_COMMANDS_DIR=""
OPENCODE_TOOLS_DIR="${HOME}/.opencode/tools"
OPENCODE_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"

FAILED=false

usage() {
    cat <<'EOF'
Usage: tools/setup.sh [OPTIONS] [SKILL...]

Install the repository's Agent Skills for OpenCode and/or Claude Code.

Options:
  -h, --help             Show this help message
  -d, --dry-run          Show every planned action without changing anything
  -v, --verbose          Enable verbose output
      --target TARGET    opencode, claude, or all (default: all)
      --scope SCOPE      user or project (default: user)
      --project-dir DIR  Project directory for --scope project (default: cwd)
      --link             Developer mode: symlink skills from this repository
                         instead of copying (breaks if the repository moves)
      --force            Replace destination entries this script did not install
      --with-agents      Generate Claude Code agent and command files
      --opencode-model V Model for the OpenCode medical-concept agent
                         (provider/model); prompts on a terminal
      --claude-model V   Model for the generated Claude agent (e.g. sonnet)
      --uninstall        Remove this script's skills and symlinks, plus the
                         OpenCode tools, agent and command it installed if
                         unchanged; with --with-agents, also the generated
                         Claude files

Positional SKILL arguments limit the install to the named skills. With no
positional arguments, every skills/*/SKILL.md is installed.

Examples:
  tools/setup.sh --target opencode
  tools/setup.sh --target claude --with-agents
  tools/setup.sh --target all
  tools/setup.sh --target all --scope project --project-dir ./my-project
  tools/setup.sh --target opencode --link
  tools/setup.sh --target opencode --opencode-model myprovider/my-model
  tools/setup.sh --target claude --with-agents --claude-model sonnet
  tools/setup.sh --uninstall --target all
  tools/setup.sh --uninstall --target claude --with-agents
  tools/setup.sh --dry-run --target claude
EOF
}

log_info() {
    printf '[INFO] %s\n' "$*"
}

log_warn() {
    printf '[WARN] %s\n' "$*" >&2
}

log_error() {
    printf '[ERROR] %s\n' "$*" >&2
}

log_dry() {
    printf '[DRY-RUN] %s\n' "$*"
}

has_target() {
    local target="$1"
    [[ "$TARGET" == "all" || "$TARGET" == "$target" ]]
}

validate_model_value() {
    local label="$1"
    local value="$2"

    if [[ "$value" =~ [[:space:]] ]]; then
        log_error "Invalid $label '$value': must not contain whitespace"
        return 1
    fi
    if [[ "$value" == *"'"* || "$value" == *'"'* ]]; then
        log_error "Invalid $label '$value': must not contain quotes"
        return 1
    fi
    if [[ "$value" == *'#'* ]]; then
        log_error "Invalid $label '$value': must not contain '#'"
        return 1
    fi
    if [[ "$value" == *": "* ]]; then
        log_error "Invalid $label '$value': must not contain ': '"
        return 1
    fi
    return 0
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --link)
                LINK_MODE=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --with-agents)
                WITH_AGENTS=true
                shift
                ;;
            --uninstall)
                UNINSTALL=true
                shift
                ;;
            --target)
                if [[ $# -lt 2 ]]; then
                    log_error "Missing value for --target"
                    exit 1
                fi
                TARGET="$2"
                shift 2
                ;;
            --target=*)
                TARGET="${1#*=}"
                shift
                ;;
            --scope)
                if [[ $# -lt 2 ]]; then
                    log_error "Missing value for --scope"
                    exit 1
                fi
                SCOPE="$2"
                shift 2
                ;;
            --scope=*)
                SCOPE="${1#*=}"
                shift
                ;;
            --project-dir)
                if [[ $# -lt 2 ]]; then
                    log_error "Missing value for --project-dir"
                    exit 1
                fi
                PROJECT_DIR="$2"
                shift 2
                ;;
            --project-dir=*)
                PROJECT_DIR="${1#*=}"
                shift
                ;;
            --opencode-model)
                if [[ $# -lt 2 ]]; then
                    log_error "Missing value for --opencode-model"
                    exit 1
                fi
                OPENCODE_MODEL="$2"
                shift 2
                ;;
            --opencode-model=*)
                OPENCODE_MODEL="${1#*=}"
                shift
                ;;
            --claude-model)
                if [[ $# -lt 2 ]]; then
                    log_error "Missing value for --claude-model"
                    exit 1
                fi
                CLAUDE_MODEL="$2"
                shift 2
                ;;
            --claude-model=*)
                CLAUDE_MODEL="${1#*=}"
                shift
                ;;
            --)
                shift
                while [[ $# -gt 0 ]]; do
                    REQUESTED_SKILLS+=("$1")
                    shift
                done
                ;;
            -*)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                REQUESTED_SKILLS+=("$1")
                shift
                ;;
        esac
    done
}

validate_options() {
    case "$TARGET" in
        opencode|claude|all) ;;
        *)
            log_error "Invalid --target '$TARGET' (expected opencode, claude, or all)"
            exit 1
            ;;
    esac

    case "$SCOPE" in
        user|project) ;;
        *)
            log_error "Invalid --scope '$SCOPE' (expected user or project)"
            exit 1
            ;;
    esac

    if [[ -n "$OPENCODE_MODEL" ]]; then
        validate_model_value "--opencode-model" "$OPENCODE_MODEL" || exit 1
    fi
    if [[ -n "$CLAUDE_MODEL" ]]; then
        validate_model_value "--claude-model" "$CLAUDE_MODEL" || exit 1
    fi
}

set_roots() {
    if [[ "$SCOPE" == "project" ]]; then
        if [[ -z "$PROJECT_DIR" ]]; then
            PROJECT_DIR="$(pwd)"
        fi
        if [[ ! -d "$PROJECT_DIR" ]]; then
            log_error "Project directory not found: $PROJECT_DIR"
            exit 1
        fi
        PROJECT_DIR="$(cd -- "$PROJECT_DIR" && pwd -P)"
        OPENCODE_SKILLS_ROOT="${PROJECT_DIR}/.opencode/skills"
        CLAUDE_SKILLS_ROOT="${PROJECT_DIR}/.claude/skills"
        CLAUDE_AGENTS_DIR="${PROJECT_DIR}/.claude/agents"
        CLAUDE_COMMANDS_DIR="${PROJECT_DIR}/.claude/commands"
    else
        OPENCODE_SKILLS_ROOT="${XDG_CONFIG_HOME:-$HOME/.config}/opencode/skills"
        CLAUDE_SKILLS_ROOT="${HOME}/.claude/skills"
        CLAUDE_AGENTS_DIR="${HOME}/.claude/agents"
        CLAUDE_COMMANDS_DIR="${HOME}/.claude/commands"
    fi
}

discover_skills() {
    local skill_md skill_name
    for skill_md in "$PROJECT_ROOT"/skills/*/SKILL.md; do
        [[ -e "$skill_md" ]] || continue
        skill_name="$(basename -- "$(dirname -- "$skill_md")")"
        DISCOVERED_SKILLS+=("$skill_name")
    done
}

select_skills() {
    if [[ ${#REQUESTED_SKILLS[@]} -eq 0 ]]; then
        SELECTED_SKILLS=("${DISCOVERED_SKILLS[@]}")
        return 0
    fi

    local requested discovered found
    for requested in "${REQUESTED_SKILLS[@]}"; do
        found=false
        for discovered in "${DISCOVERED_SKILLS[@]}"; do
            if [[ "$requested" == "$discovered" ]]; then
                found=true
                break
            fi
        done
        if [[ "$found" != true ]]; then
            log_error "Unknown skill: $requested"
            exit 1
        fi
        SELECTED_SKILLS+=("$requested")
    done
}

set_target_roots() {
    TARGET_ROOTS=()
    if has_target opencode; then
        TARGET_ROOTS+=("$OPENCODE_SKILLS_ROOT")
    fi
    if has_target claude; then
        TARGET_ROOTS+=("$CLAUDE_SKILLS_ROOT")
    fi
}

is_our_symlink() {
    local path="$1" target
    [[ -L "$path" ]] || return 1
    target="$(readlink -f -- "$path" 2>/dev/null)" || return 1
    [[ "$target" == "$PROJECT_ROOT"/skills/* ]]
}

is_our_install() {
    local path="$1"
    if [[ -L "$path" ]]; then
        is_our_symlink "$path"
        return $?
    fi
    [[ -f "$path/$MARKER" ]]
}

remove_entry() {
    local path="$1"
    if [[ -L "$path" ]]; then
        rm -f -- "$path"
    elif [[ -d "$path" ]]; then
        rm -r -- "$path"
    else
        rm -f -- "$path"
    fi
}

validate_skill() {
    local skill="$1"
    local skill_dir="${PROJECT_ROOT}/skills/${skill}"
    local skill_md="${skill_dir}/SKILL.md"
    local errors=()
    local fm_file name desc_len

    if [[ ! -f "$skill_md" ]]; then
        log_error "Validation failed for '$skill': SKILL.md not found"
        return 1
    fi

    fm_file="$(mktemp "${TMPDIR:-/tmp}/swrs-fm.XXXXXX")"

    if ! awk '
        NR==1 { if ($0 !~ /^---[[:space:]]*$/) exit 1; inside=1; next }
        inside && /^---[[:space:]]*$/ { closed=1; exit 0 }
        inside { print }
        END { if (!closed) exit 1 }
    ' "$skill_md" > "$fm_file"; then
        errors+=("missing YAML frontmatter delimited by ---")
    fi

    name="$(awk '/^name:[[:space:]]*/ { sub(/^name:[[:space:]]*/, "", $0); print; exit }' "$fm_file")"
    name="$(printf '%s' "$name" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    name="${name#\"}"
    name="${name%\"}"
    name="${name#\'}"
    name="${name%\'}"

    if [[ -z "$name" ]]; then
        errors+=("missing 'name' in frontmatter")
    else
        if [[ "$name" != "$skill" ]]; then
            errors+=("name '$name' does not match directory '$skill'")
        fi
        if (( ${#name} > 64 )); then
            errors+=("name exceeds 64 characters")
        fi
        if [[ ! "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
            errors+=("name must be lowercase letters, digits and single hyphens, with no leading or trailing hyphen")
        fi
        if [[ "$name" == *claude* || "$name" == *anthropic* ]]; then
            errors+=("name must not contain 'claude' or 'anthropic'")
        fi
    fi

    if ! grep -qE '^description:' "$fm_file"; then
        errors+=("missing 'description' in frontmatter")
    else
        desc_len="$(awk '
            BEGIN { cap=0; total=0; first=1 }
            /^description:[[:space:]]*/ {
                cap=1
                rest=$0
                sub(/^description:[[:space:]]*/, "", rest)
                sub(/[[:space:]]+$/, "", rest)
                if (rest ~ /^[>|][+-]?$/) rest=""
                if (rest != "") { total += length(rest); first=0 }
                next
            }
            cap==1 {
                if ($0 ~ /^[^[:space:]]/) { cap=0; next }
                line=$0
                sub(/^[[:space:]]+/, "", line)
                sub(/[[:space:]]+$/, "", line)
                if (line == "") next
                if (!first) total += 1
                total += length(line)
                first=0
            }
            END { print total }
        ' "$fm_file")"
        if (( desc_len > 1024 )); then
            errors+=("description is ${desc_len} characters (max 1024)")
        fi
    fi

    local raw target
    while IFS= read -r raw; do
        [[ -z "$raw" ]] && continue
        target="${raw#](}"
        target="${target%)}"
        target="$(printf '%s' "$target" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]].*$//')"
        target="${target%%#*}"
        [[ -z "$target" ]] && continue
        case "$target" in
            http://*|https://*|mailto:*|/*) continue ;;
        esac
        if [[ ! -f "${skill_dir}/${target}" ]]; then
            errors+=("broken relative link: $target")
        fi
    done < <(grep -oE '\]\([^)]+\)' "$skill_md" || true)

    rm -f -- "$fm_file"

    if [[ ${#errors[@]} -gt 0 ]]; then
        log_error "Validation failed for skill '$skill':"
        local error
        for error in "${errors[@]}"; do
            printf '  - %s\n' "$error" >&2
        done
        return 1
    fi

    if [[ "$VERBOSE" == true ]]; then
        log_info "Validated skill: $skill"
    fi
    return 0
}

copy_tree() {
    local src="$1"
    local dest="$2"

    mkdir -p "$dest"
    if command -v rsync >/dev/null 2>&1; then
        rsync -a \
            --exclude '*.zip' \
            --exclude '.skillfish.json' \
            --exclude '__pycache__' \
            "$src/" "$dest/"
    else
        cp -R "$src/." "$dest/"
    fi
}

prune_bundle() {
    local dir="$1"

    find "$dir" -type f -name '*.zip' -delete
    find "$dir" -type f -name '.skillfish.json' -delete
    find "$dir" -type f -size 0 ! -name '__init__.py' -delete
    find "$dir" -type d -name '__pycache__' -prune -exec rm -rf -- {} +
}

build_bundle() {
    local src="$1"
    local dest="$2"
    local sub

    mkdir -p "$dest"
    cp -- "$src/SKILL.md" "$dest/SKILL.md" || return 1

    for sub in references scripts assets; do
        if [[ -d "$src/$sub" ]]; then
            copy_tree "$src/$sub" "$dest/$sub" || return 1
        fi
    done

    prune_bundle "$dest" || return 1
}

install_skill_copy() {
    local skill="$1"
    local root="$2"
    local src="${PROJECT_ROOT}/skills/${skill}"
    local dest="${root}/${skill}"
    local tmp built

    if [[ -e "$dest" || -L "$dest" ]]; then
        if is_our_install "$dest"; then
            if [[ "$DRY_RUN" == false && "$VERBOSE" == true ]]; then
                log_info "Replacing existing installation: $dest"
            fi
        elif [[ "$FORCE" == true ]]; then
            if [[ "$DRY_RUN" == true ]]; then
                log_dry "Would replace foreign install: $dest"
            else
                log_warn "Replacing foreign install after build (--force): $dest"
            fi
        else
            log_warn "Skipping $dest: not installed by this script (use --force to replace)"
            return 0
        fi
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log_dry "Would install skill $skill -> $dest"
        return 0
    fi

    # Stage inside the destination root so the final mv is a same-filesystem rename.
    mkdir -p "$root"
    tmp="$(mktemp -d "${root}/.swrs-stage.XXXXXX")"
    built="${tmp}/${skill}"
    if ! build_bundle "$src" "$built"; then
        rm -rf -- "$tmp"
        log_error "Failed to build bundle for '$skill'"
        FAILED=true
        return 0
    fi

    if [[ -e "$dest" || -L "$dest" ]]; then
        remove_entry "$dest"
    fi
    mv -- "$built" "$dest"
    : > "$dest/$MARKER"
    rm -rf -- "$tmp"
    log_info "Installed skill: $dest"
}

install_skill_link() {
    local skill="$1"
    local root="$2"
    local src="${PROJECT_ROOT}/skills/${skill}"
    local dest="${root}/${skill}"

    if [[ -e "$dest" || -L "$dest" ]]; then
        if is_our_install "$dest"; then
            :
        elif [[ "$FORCE" == true ]]; then
            if [[ "$DRY_RUN" == true ]]; then
                log_dry "Would remove foreign entry: $dest"
            else
                log_warn "Removing foreign entry (--force): $dest"
                remove_entry "$dest"
            fi
        else
            log_warn "Skipping $dest: not installed by this script (use --force to replace)"
            return 0
        fi
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log_dry "Would link skill $dest -> $src"
        return 0
    fi

    mkdir -p "$root"
    if [[ -e "$dest" || -L "$dest" ]]; then
        remove_entry "$dest"
    fi
    ln -s -- "$src" "$dest"
    log_info "Linked skill: $dest -> $src"
}

uninstall_skill() {
    local skill="$1"
    local root="$2"
    local dest="${root}/${skill}"

    if [[ ! -e "$dest" && ! -L "$dest" ]]; then
        if [[ "$VERBOSE" == true ]]; then
            log_info "Nothing to remove: $dest"
        fi
        return 0
    fi

    if is_our_symlink "$dest"; then
        if [[ "$DRY_RUN" == true ]]; then
            log_dry "Would remove symlink: $dest"
        else
            rm -f -- "$dest"
            log_info "Removed symlink: $dest"
        fi
        return 0
    fi

    if [[ -L "$dest" ]]; then
        log_warn "Skipping $dest: symlink does not point into this repository"
        return 0
    fi

    if [[ -d "$dest" && -f "$dest/$MARKER" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            log_dry "Would remove installed skill: $dest"
        else
            rm -r -- "$dest"
            log_info "Removed installed skill: $dest"
        fi
        return 0
    fi

    log_warn "Skipping $dest: not installed by this script"
}

file_hash() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum -- "$1" | awk '{print $1}'
    else
        shasum -a 256 -- "$1" | awk '{print $1}'
    fi
}

# The tools manifest records "<sha256>TAB<path relative to the tools dir>" for every
# file this script copied there, so later runs can tell "ours and unchanged" (safe to
# update or remove) from "yours" (left alone unless --force).
tools_manifest() {
    printf '%s/%s' "$OPENCODE_TOOLS_DIR" "$MARKER"
}

manifest_get() {
    local manifest
    manifest="$(tools_manifest)"
    [[ -f "$manifest" ]] || return 0
    awk -F'\t' -v rel="$1" '$2 == rel { print $1; exit }' "$manifest"
}

manifest_drop() {
    local manifest tmp
    manifest="$(tools_manifest)"
    [[ -f "$manifest" ]] || return 0
    tmp="$(mktemp "${OPENCODE_TOOLS_DIR}/.swrs-manifest.XXXXXX")"
    awk -F'\t' -v rel="$1" '$2 != rel' "$manifest" > "$tmp"
    if [[ -s "$tmp" ]]; then
        mv -- "$tmp" "$manifest"
    else
        rm -f -- "$tmp" "$manifest"
    fi
}

manifest_set() {
    local rel="$1" hash="$2" manifest tmp
    manifest="$(tools_manifest)"
    mkdir -p "$OPENCODE_TOOLS_DIR"
    tmp="$(mktemp "${OPENCODE_TOOLS_DIR}/.swrs-manifest.XXXXXX")"
    if [[ -f "$manifest" ]]; then
        awk -F'\t' -v rel="$rel" '$2 != rel' "$manifest" > "$tmp"
    fi
    printf '%s\t%s\n' "$hash" "$rel" >> "$tmp"
    mv -- "$tmp" "$manifest"
}

install_tool_file() {
    local src="$1" rel="$2"
    local dest="${OPENCODE_TOOLS_DIR}/${rel}"
    local new_hash cur_hash="" rec_hash

    new_hash="$(file_hash "$src")"

    if [[ -e "$dest" || -L "$dest" ]]; then
        if [[ -f "$dest" && ! -L "$dest" ]]; then
            cur_hash="$(file_hash "$dest")"
        fi
        if [[ "$cur_hash" == "$new_hash" ]]; then
            [[ "$DRY_RUN" == true ]] || manifest_set "$rel" "$new_hash"
            if [[ "$VERBOSE" == true ]]; then
                log_info "Up to date: $dest"
            fi
            return 0
        fi
        rec_hash="$(manifest_get "$rel")"
        if [[ -n "$rec_hash" && "$cur_hash" == "$rec_hash" ]]; then
            : # installed by this script and unchanged since: safe to update
        elif [[ "$FORCE" == true ]]; then
            if [[ "$DRY_RUN" == false ]]; then
                log_warn "Replacing file not installed by this script (--force): $dest"
            fi
        else
            log_warn "Skipping $dest: not installed by this script, or changed since (use --force to replace)"
            return 0
        fi
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log_dry "Would copy: $src -> $dest"
        return 0
    fi

    if [[ "$VERBOSE" == true ]]; then
        log_info "Copying: $src -> $dest"
    fi
    mkdir -p "$(dirname -- "$dest")"
    if [[ -L "$dest" ]]; then
        rm -f -- "$dest"
    fi
    cp -- "$src" "$dest"
    manifest_set "$rel" "$new_hash"
}

read_model_value() {
    awk '
        /^model:[[:space:]]*/ {
            sub(/^model:[[:space:]]*/, "", $0)
            sub(/[[:space:]]+$/, "", $0)
            print
            exit
        }
    ' "$1"
}

resolve_opencode_model() {
    local dest="$1"
    local value=""
    local branch=""

    if [[ -n "$OPENCODE_MODEL" ]]; then
        value="$OPENCODE_MODEL"
        branch="flag"
    elif [[ -f "$dest" ]]; then
        value="$(read_model_value "$dest")"
        if [[ -n "$value" ]]; then
            branch="installed"
        fi
    fi

    if [[ -z "$value" && -t 0 && "$DRY_RUN" == false && "$UNINSTALL" == false ]]; then
        local answer=""
        printf 'OpenCode model for the medical-concept agent (provider/model, empty to skip): ' >&2
        IFS= read -r answer || answer=""
        value="$answer"
        branch="prompt"
    fi

    if [[ -z "$value" ]]; then
        branch="default"
    elif ! validate_model_value "OpenCode model" "$value"; then
        exit 1
    fi

    RESOLVED_OPENCODE_MODEL="$value"
    OPENCODE_MODEL_BRANCH="$branch"
}

generate_opencode_agent() {
    local out_file="$1"
    local model="$2"

    awk -v model="$model" '
        /^#[[:space:]]*model:/ {
            if (model != "") print "model: " model
            next
        }
        { print }
    ' "$PROJECT_ROOT/agents/medical-concept.md" > "$out_file"
}

install_opencode_extras() {
    log_info "Installing OpenCode tool, agent, and command files"

    local scripts_dir script_file ts_file agent_dest tmp

    for scripts_dir in "$PROJECT_ROOT"/skills/*/scripts; do
        [[ -d "$scripts_dir" ]] || continue
        for script_file in "$scripts_dir"/*.py; do
            [[ -f "$script_file" ]] || continue
            install_tool_file "$script_file" "$(basename -- "$script_file")"
        done
    done

    for ts_file in "$PROJECT_ROOT"/src/*.ts; do
        [[ -f "$ts_file" ]] || continue
        install_tool_file "$ts_file" "$(basename -- "$ts_file")"
    done

    for ts_file in "$PROJECT_ROOT"/src/lib/*; do
        [[ -f "$ts_file" ]] || continue
        install_tool_file "$ts_file" "lib/$(basename -- "$ts_file")"
    done

    if [[ -f "$PROJECT_ROOT/agents/medical-concept.md" ]]; then
        agent_dest="${OPENCODE_CONFIG_DIR}/agents/medical-concept.md"
        resolve_opencode_model "$agent_dest"

        tmp="$(mktemp -d "${TMPDIR:-/tmp}/swrs-opencode.XXXXXX")"
        generate_opencode_agent "${tmp}/medical-concept.md" "$RESOLVED_OPENCODE_MODEL"

        local identical=false will_write=false
        if [[ -f "$agent_dest" ]] && cmp -s -- "${tmp}/medical-concept.md" "$agent_dest"; then
            identical=true
        fi
        if [[ ! -e "$agent_dest" && ! -L "$agent_dest" ]]; then
            will_write=true
        elif [[ "$FORCE" == true && "$identical" == false ]]; then
            will_write=true
        fi

        if [[ "$DRY_RUN" == true ]]; then
            case "$OPENCODE_MODEL_BRANCH" in
                flag)
                    log_dry "OpenCode agent model: ${RESOLVED_OPENCODE_MODEL} (from --opencode-model)"
                    ;;
                installed)
                    log_dry "OpenCode agent model: ${RESOLVED_OPENCODE_MODEL} (preserved from installed file)"
                    ;;
                *)
                    log_dry "OpenCode agent model: none (OpenCode default model)"
                    ;;
            esac
        elif [[ -z "$RESOLVED_OPENCODE_MODEL" && "$will_write" == true ]]; then
            log_warn "No OpenCode model set for medical-concept; the agent will use OpenCode's default model. Pass --opencode-model or edit the installed agent to pin one."
        fi

        install_generated_file "${tmp}/medical-concept.md" "$agent_dest"
        rm -rf -- "$tmp"
    fi

    for ts_file in "$PROJECT_ROOT"/agents/*.md; do
        [[ -f "$ts_file" ]] || continue
        [[ "$(basename -- "$ts_file")" == "medical-concept.md" ]] && continue
        install_generated_file "$ts_file" "${OPENCODE_CONFIG_DIR}/agents/$(basename -- "$ts_file")"
    done

    for ts_file in "$PROJECT_ROOT"/commands/*.md; do
        [[ -f "$ts_file" ]] || continue
        install_generated_file "$ts_file" "${OPENCODE_CONFIG_DIR}/commands/$(basename -- "$ts_file")"
    done
}

install_generated_file() {
    local generated="$1"
    local dest="$2"

    if [[ -e "$dest" || -L "$dest" ]]; then
        if [[ -f "$dest" ]] && cmp -s -- "$generated" "$dest"; then
            if [[ "$VERBOSE" == true ]]; then
                log_info "Up to date: $dest"
            fi
            return 0
        fi
        if [[ "$FORCE" != true ]]; then
            log_warn "Skipping $dest: differs from generated file (use --force to replace)"
            return 0
        fi
        if [[ "$DRY_RUN" == true ]]; then
            log_dry "Would replace: $dest"
        else
            log_warn "Replacing existing file (--force): $dest"
            remove_entry "$dest"
        fi
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log_dry "Would write: $dest"
        return 0
    fi

    mkdir -p "$(dirname -- "$dest")"
    cp -- "$generated" "$dest"
    log_info "Wrote: $dest"
}

generate_claude_files() {
    local out_dir="$1"
    local claude_model="${2:-}"
    local agent_out="${out_dir}/medical-concept.md"
    local command_out="${out_dir}/ask-medical.md"

    awk -v model="$claude_model" '
        NR==1 && /^---[[:space:]]*$/ { print; infm=1; next }
        infm && /^---[[:space:]]*$/ {
            print "name: medical-concept"
            print "tools: WebFetch"
            if (model != "") print "model: " model
            print
            infm=0
            next
        }
        infm {
            if ($0 ~ /^description:/) { print; desc=1; next }
            if (desc && $0 ~ /^[[:space:]]+[^[:space:]]/) { print; next }
            desc=0
            next
        }
        { print }
    ' "$PROJECT_ROOT/agents/medical-concept.md" > "$agent_out"

    awk '
        NR==1 && /^---[[:space:]]*$/ { print; infm=1; next }
        infm && /^---[[:space:]]*$/ {
            print "argument-hint: <clinical term or question>"
            print
            print "Use the medical-concept subagent to answer this medical/clinical terminology question:"
            print ""
            print "$ARGUMENTS"
            infm=0
            done=1
            next
        }
        infm {
            if ($0 ~ /^description:/) { print; desc=1; next }
            if (desc && $0 ~ /^[[:space:]]+/) { print; next }
            desc=0
            next
        }
        done==1 { next }
        { print }
    ' "$PROJECT_ROOT/commands/ask-medical.md" > "$command_out"
}

install_claude_extras() {
    log_info "Generating Claude Code agent and command files"

    local tmp

    tmp="$(mktemp -d "${TMPDIR:-/tmp}/swrs-claude.XXXXXX")"
    generate_claude_files "$tmp" "$CLAUDE_MODEL"

    install_generated_file "${tmp}/medical-concept.md" "${CLAUDE_AGENTS_DIR}/medical-concept.md"
    install_generated_file "${tmp}/ask-medical.md" "${CLAUDE_COMMANDS_DIR}/ask-medical.md"

    rm -rf -- "$tmp"
}

uninstall_generated_file() {
    local generated="$1"
    local dest="$2"

    if [[ ! -e "$dest" && ! -L "$dest" ]]; then
        if [[ "$VERBOSE" == true ]]; then
            log_info "Nothing to remove: $dest"
        fi
        return 0
    fi

    if [[ -f "$dest" ]] && cmp -s -- "$generated" "$dest"; then
        if [[ "$DRY_RUN" == true ]]; then
            log_dry "Would remove generated file: $dest"
        else
            rm -f -- "$dest"
            log_info "Removed generated file: $dest"
        fi
        return 0
    fi

    log_warn "Skipping $dest: differs from the file this script would generate"
}

uninstall_claude_extras() {
    log_info "Removing generated Claude Code agent and command files"

    local tmp agent_dest model

    agent_dest="${CLAUDE_AGENTS_DIR}/medical-concept.md"
    model="$CLAUDE_MODEL"
    if [[ -z "$model" && -f "$agent_dest" ]]; then
        model="$(read_model_value "$agent_dest")"
    fi

    tmp="$(mktemp -d "${TMPDIR:-/tmp}/swrs-claude.XXXXXX")"
    generate_claude_files "$tmp" "$model"

    uninstall_generated_file "${tmp}/medical-concept.md" "${CLAUDE_AGENTS_DIR}/medical-concept.md"
    uninstall_generated_file "${tmp}/ask-medical.md" "${CLAUDE_COMMANDS_DIR}/ask-medical.md"

    rm -rf -- "$tmp"
}

uninstall_opencode_extras() {
    log_info "Removing OpenCode tool, agent, and command files installed by this script"

    local manifest rec_hash rel dest cur_hash tmp agent_dest model src_file

    manifest="$(tools_manifest)"
    if [[ -f "$manifest" ]]; then
        while IFS=$'\t' read -r rec_hash rel; do
            [[ -n "$rel" ]] || continue
            dest="${OPENCODE_TOOLS_DIR}/${rel}"
            if [[ ! -e "$dest" && ! -L "$dest" ]]; then
                [[ "$DRY_RUN" == true ]] || manifest_drop "$rel"
                continue
            fi
            cur_hash=""
            if [[ -f "$dest" && ! -L "$dest" ]]; then
                cur_hash="$(file_hash "$dest")"
            fi
            if [[ "$cur_hash" != "$rec_hash" ]]; then
                log_warn "Skipping $dest: changed since this script installed it"
            elif [[ "$DRY_RUN" == true ]]; then
                log_dry "Would remove: $dest"
            else
                rm -f -- "$dest"
                manifest_drop "$rel"
                log_info "Removed: $dest"
            fi
        done < "$manifest"
        if [[ "$DRY_RUN" == false ]]; then
            rmdir "${OPENCODE_TOOLS_DIR}/lib" 2>/dev/null || true
        fi
    elif [[ "$VERBOSE" == true ]]; then
        log_info "No tools manifest at $manifest; nothing to remove from ${OPENCODE_TOOLS_DIR}"
    fi

    tmp="$(mktemp -d "${TMPDIR:-/tmp}/swrs-opencode.XXXXXX")"

    if [[ -f "$PROJECT_ROOT/agents/medical-concept.md" ]]; then
        agent_dest="${OPENCODE_CONFIG_DIR}/agents/medical-concept.md"
        model=""
        if [[ -f "$agent_dest" ]]; then
            model="$(read_model_value "$agent_dest")"
        fi
        generate_opencode_agent "${tmp}/medical-concept.md" "$model"
        uninstall_generated_file "${tmp}/medical-concept.md" "$agent_dest"
    fi

    for src_file in "$PROJECT_ROOT"/agents/*.md; do
        [[ -f "$src_file" ]] || continue
        [[ "$(basename -- "$src_file")" == "medical-concept.md" ]] && continue
        uninstall_generated_file "$src_file" "${OPENCODE_CONFIG_DIR}/agents/$(basename -- "$src_file")"
    done

    for src_file in "$PROJECT_ROOT"/commands/*.md; do
        [[ -f "$src_file" ]] || continue
        uninstall_generated_file "$src_file" "${OPENCODE_CONFIG_DIR}/commands/$(basename -- "$src_file")"
    done

    rm -rf -- "$tmp"
}

check_prerequisites() {
    if [[ "$UNINSTALL" == false ]] && ! command -v uv >/dev/null 2>&1; then
        log_warn "uv was not found on PATH. The bundled helper scripts declare their dependencies inline (PEP 723) and are meant to be run with 'uv run'. Install uv (https://docs.astral.sh/uv/), or install rdflib and fuxi yourself and run the scripts with python3."
    fi
}

main() {
    parse_args "$@"
    validate_options
    set_roots
    discover_skills
    select_skills
    set_target_roots

    log_info "Repository: $PROJECT_ROOT"
    if [[ "$SCOPE" == "project" ]]; then
        log_info "Scope: project (${PROJECT_DIR})"
    else
        log_info "Scope: user"
    fi
    log_info "Target(s): $TARGET"
    if [[ "$LINK_MODE" == true ]]; then
        log_info "Mode: link"
    else
        log_info "Mode: copy"
    fi
    if [[ "$DRY_RUN" == true ]]; then
        log_info "Running in dry-run mode (no changes will be made)"
    fi

    check_prerequisites

    local skill root
    for skill in "${SELECTED_SKILLS[@]}"; do
        if [[ "$UNINSTALL" == true ]]; then
            for root in "${TARGET_ROOTS[@]}"; do
                uninstall_skill "$skill" "$root"
            done
            continue
        fi

        if ! validate_skill "$skill"; then
            FAILED=true
            continue
        fi

        for root in "${TARGET_ROOTS[@]}"; do
            if [[ "$LINK_MODE" == true ]]; then
                install_skill_link "$skill" "$root"
            else
                install_skill_copy "$skill" "$root"
            fi
        done
    done

    if [[ "$UNINSTALL" == true ]]; then
        if has_target opencode && [[ "$SCOPE" == "user" ]]; then
            uninstall_opencode_extras
        fi
        if has_target claude && [[ "$WITH_AGENTS" == true ]]; then
            uninstall_claude_extras
        fi
    else
        if has_target opencode && [[ "$SCOPE" == "user" ]]; then
            install_opencode_extras
        fi
        if has_target claude && [[ "$WITH_AGENTS" == true ]]; then
            install_claude_extras
        fi
    fi

    if [[ "$FAILED" == true ]]; then
        log_error "Completed with validation errors; see the messages above."
        exit 1
    fi

    if [[ "$UNINSTALL" == true ]]; then
        log_info "Uninstall complete."
    else
        log_info "Installation complete."
    fi
}

main "$@"
