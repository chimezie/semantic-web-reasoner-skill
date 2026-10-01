#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s inherit_errexit
IFS=$'\n\t'

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
readonly TOOLS_DIR="$HOME/.opencode/tools"
readonly SKILL_LOCK="$HOME/.agents/.skill-lock.json"
readonly PLUGIN_DIR="$HOME/.opencode/plugins/semantic-web-agent"
readonly AGENTS_DIR_DST="$HOME/.config/opencode/agents"
readonly COMMANDS_DIR_DST="$HOME/.config/opencode/commands"
readonly DEFAULT_MEDICAL_MODEL="openai/gpt-4o"

# Discover skill names from the skills/ directory
discover_skills() {
  local skills=()
  for skill_dir in "$REPO_DIR/skills/"*/; do
    [[ -d "$skill_dir" ]] && skills+=("$(basename "$skill_dir")")
  done
  printf '%s\n' "${skills[@]}"
}

DRY_RUN=false

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Deploy skills: TypeScript tools, Python backends,
SKILL.md(s), subagents, and commands to OpenCode's tool, skill,
agent, and command directories.

Options:
  -n, --dry-run   Show what would be done without making changes
  -h, --help      Show this help message and exit

Environment:
  OPENCODE_MEDICAL_MODEL  Model for the medical-concept subagent
                          (default: $DEFAULT_MEDICAL_MODEL)
EOF
  exit 0
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) usage ;;
      -n|--dry-run) DRY_RUN=true; shift ;;
      *) printf "Unknown option: %s\n" "$1" >&2; usage ;;
    esac
  done
}

check_prereqs() {
  local missing=false
  for cmd in node npm; do
    if ! command -v "$cmd" &>/dev/null; then
      printf "Error: '%s' is required but not on PATH.\n" "$cmd" >&2
      missing=true
    fi
  done
  if [[ $missing == true ]]; then exit 1; fi
}

run() {
  if $DRY_RUN; then
    printf "[dry-run] %s\n" "$*"
  else
    "$@"
  fi
}

deploy_python_scripts() {
  run mkdir -p "$TOOLS_DIR"

  # Copy from skills/.../scripts/
  for py in "$REPO_DIR/skills/semantic-web-agent/scripts/"*.py; do
    [[ -f "$py" ]] && run cp "$py" "$TOOLS_DIR/"
  done

  # Overwrite dir-ontology.py with the richer version from src/
  if [[ -f "$REPO_DIR/src/dir-ontology.py" ]]; then
    run cp "$REPO_DIR/src/dir-ontology.py" "$TOOLS_DIR/dir-ontology.py"
  fi

  run chmod +x "$TOOLS_DIR"/*.py
}

deploy_ts_tools() {
  run mkdir -p "$TOOLS_DIR"
  for ts in "$REPO_DIR"/src/*.ts; do
    local base
    base="$(basename "$ts")"
    # Skip the plugin entry file — it is not a standalone tool definition
    [[ "$base" == "index.ts" ]] && continue
    run cp "$ts" "$TOOLS_DIR/"
  done

  # Shared support modules (e.g. lib/auto-config.ts) imported by standalone tools
  if [[ -d "$REPO_DIR/src/lib" ]]; then
    run mkdir -p "$TOOLS_DIR/lib"
    for ts in "$REPO_DIR"/src/lib/*.ts; do
      [[ -f "$ts" ]] && run cp "$ts" "$TOOLS_DIR/lib/"
    done
  fi
}

deploy_skill_docs() {
  while IFS= read -r skill_name; do
    local target="$HOME/.opencode/skills/$skill_name"
    run mkdir -p "$target"
    run cp -r "$REPO_DIR/skills/$skill_name/"* "$target/"
  done < <(discover_skills)
}

deploy_plugin() {
  run mkdir -p "$PLUGIN_DIR"
  # Deploy compiled plugin output so OpenCode can load it as a local plugin
  run cp -r "$REPO_DIR/dist/" "$PLUGIN_DIR/dist/"
  run cp "$REPO_DIR/package.json" "$PLUGIN_DIR/"
  if [[ -f "$REPO_DIR/package-lock.json" ]]; then
    run cp "$REPO_DIR/package-lock.json" "$PLUGIN_DIR/"
  fi
}

deploy_skill_to_agents() {
  run mkdir -p "$HOME/.claude/skills"
  while IFS= read -r skill_name; do
    local target="$HOME/.agents/skills/$skill_name"
    run mkdir -p "$target"
    run cp -r "$REPO_DIR/skills/$skill_name/"* "$target/"
    # Create a symlink in ~/.claude/skills/ for compatibility
    run ln -snf "$target" "$HOME/.claude/skills/$skill_name"
  done < <(discover_skills)
}

deploy_agent_definitions() {
  run mkdir -p "$AGENTS_DIR_DST"
  for agent in "$REPO_DIR/agents/"*.md; do
    [[ -f "$agent" ]] && run cp "$agent" "$AGENTS_DIR_DST/"
  done

  local model="${OPENCODE_MEDICAL_MODEL:-$DEFAULT_MEDICAL_MODEL}"

# This is not the upstream provider’s actual model identifier
#  if [[ $model != ?*"/"?* || $model == *"|"* ]]; then
#    printf "Error: invalid model '%s'. Expected format: provider/model (e.g., openai/gpt-4o)\n" "$model" >&2
#    return 1
#  fi

  local agent_file="$AGENTS_DIR_DST/medical-concept.md"
  if [[ -f "$agent_file" ]]; then
    if $DRY_RUN; then
      printf "[dry-run] sed -i 's|#model: \\.\\.replace with your model\\.\\.|model: %s|' %s\n" "$model" "$agent_file"
    else
      sed -i "s|#model: \\.\\.replace with your model\\.\\.|model: $model|" "$agent_file"
    fi
  fi
}

deploy_commands() {
  run mkdir -p "$COMMANDS_DIR_DST"
  for cmd in "$REPO_DIR/commands/"*.md; do
    [[ -f "$cmd" ]] && run cp "$cmd" "$COMMANDS_DIR_DST/"
  done
}

register_skill_lock() {
  if $DRY_RUN; then
    printf "[dry-run] Register skills in %s\n" "$SKILL_LOCK"
    return
  fi
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local skill_names=()
  while IFS= read -r name; do
    skill_names+=("$name")
  done < <(discover_skills)
  python3 -c "
import json, os, sys
lock_path = os.path.expanduser('$SKILL_LOCK')
with open(lock_path) as f:
    lock = json.load(f)
skills = lock.setdefault('skills', {})
for name in sys.argv[1:]:
    skills[name] = {
        'source': 'local',
        'sourceType': 'local',
        'sourceUrl': '',
        'skillPath': f'{name}/SKILL.md',
        'skillFolderHash': '',
        'installedAt': '$ts',
        'updatedAt': '$ts'
    }
with open(lock_path, 'w') as f:
    json.dump(lock, f, indent=2, sort_keys=True)
    f.write('\n')
" "${skill_names[@]}"
}

clean_stale() {
  # Compute managed filenames from the repo
  local stale_py=() stale_ts=()

  for py in "$REPO_DIR/skills/semantic-web-agent/scripts/"*.py; do
    [[ -f "$py" ]] && stale_py+=("$(basename "$py")")
  done
  # dir-ontology.py from src/ overrides the one from skills/ during deploy
  # (already covered by the skills glob above for cleanup purposes)

  for ts in "$REPO_DIR"/src/*.ts; do
    local base; base="$(basename "$ts")"
    [[ "$base" != "index.ts" ]] && stale_ts+=("$base")
  done

  # Remove only managed files from tools directory
  for f in "${stale_py[@]}"; do
    run rm -f "$TOOLS_DIR/$f"
  done
  for f in "${stale_ts[@]}"; do
    run rm -f "$TOOLS_DIR/$f"
  done
  run rm -rf "$TOOLS_DIR/__pycache__"
  run rm -rf "$TOOLS_DIR/lib"

  # Remove stale skill deployments
  while IFS= read -r skill_name; do
    run rm -rf "$HOME/.opencode/skills/$skill_name"
    run rm -rf "$HOME/.agents/skills/$skill_name"
    run rm -f "$HOME/.claude/skills/$skill_name"
  done < <(discover_skills)
  # Remove stale agent deployments
  for agent in "$REPO_DIR/agents/"*.md; do
    [[ -f "$agent" ]] && run rm -f "$AGENTS_DIR_DST/$(basename "$agent")"
  done
  # Remove stale command deployments
  for cmd in "$REPO_DIR/commands/"*.md; do
    [[ -f "$cmd" ]] && run rm -f "$COMMANDS_DIR_DST/$(basename "$cmd")"
  done
}

main() {
  parse_args "$@"
  check_prereqs

  printf "=== Building TypeScript plugin ===\n"
  if $DRY_RUN; then
    printf "[dry-run] cd %s && npm run build\n" "$REPO_DIR"
  else
    (cd "$REPO_DIR" && npm run build)
  fi

  clean_stale

  printf "=== Deploying Python backend scripts to %s ===\n" "$TOOLS_DIR"
  deploy_python_scripts

  printf "=== Deploying standalone .ts tool definitions ===\n"
  deploy_ts_tools

  printf "=== Deploying skill documentation ===\n"
  deploy_skill_docs

  printf "=== Deploying skills to agents directory ===\n"
  deploy_skill_to_agents

  printf "=== Deploying agent definitions to %s ===\n" "$AGENTS_DIR_DST"
  deploy_agent_definitions

  printf "=== Deploying commands to %s ===\n" "$COMMANDS_DIR_DST"
  deploy_commands

  printf "=== Registering skills in lock file ===\n"
  register_skill_lock

  printf "=== Deploying compiled plugin to %s ===\n" "$PLUGIN_DIR"
  deploy_plugin

  printf "\n=== Deploy complete ===\n"
  if ! $DRY_RUN; then
    printf "Python scripts deployed:\n"
    ls -la "$TOOLS_DIR/"*.py
    printf "\nTypeScript tool definitions:\n"
    ls -la "$TOOLS_DIR/"*.ts
    printf "\nSkill documentation:\n"
    while IFS= read -r skill_name; do
      printf "  %s:\n" "$HOME/.opencode/skills/$skill_name"
      ls -la "$HOME/.opencode/skills/$skill_name/"
    done < <(discover_skills)
    printf "\nAgents skill directories:\n"
    while IFS= read -r skill_name; do
      printf "  %s:\n" "$HOME/.agents/skills/$skill_name"
      ls -la "$HOME/.agents/skills/$skill_name/"
    done < <(discover_skills)
    printf "\nAgents deployed:\n"
    ls -la "$AGENTS_DIR_DST/"*.md 2>/dev/null || printf "  (none)\n"
    printf "\nCommands deployed:\n"
    ls -la "$COMMANDS_DIR_DST/"*.md 2>/dev/null || printf "  (none)\n"
    printf "\nCompiled plugin:\n"
    ls -la "$PLUGIN_DIR/dist/" 2>/dev/null || printf "  (empty)\n"
  fi
}

main "$@"
