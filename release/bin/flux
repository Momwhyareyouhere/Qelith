#!/usr/bin/env bash
set -euo pipefail

SELF_PATH="${BASH_SOURCE[0]}"
if command -v readlink >/dev/null 2>&1; then
  REAL_PATH="$(readlink -f "$SELF_PATH" 2>/dev/null || true)"
  if [[ -n "${REAL_PATH:-}" ]]; then
    SELF_PATH="$REAL_PATH"
  fi
fi
ROOT_DIR="$(cd "$(dirname "$SELF_PATH")" && pwd)"
AS_BIN="${AS:-as}"
LD_BIN="${LD:-ld}"
FLUX_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/flux"
FLUX_BOOTSTRAP_BIN="$FLUX_DATA_DIR/flux0"

declare -A FN_BODY
ROOT_FN=""
HALT=0
EXIT_CODE=0
CALL_DEPTH=0

usage() {
  cat <<'EOF'
usage:
  flux build <input.flux> [output_binary]
  flux run   <input.flux>

examples:
  flux run examples/hello.flux
  flux build examples/hello.flux build/hello
EOF
}

die() {
  echo "flux: $*" >&2
  exit 1
}

require_tools() {
  command -v "$AS_BIN" >/dev/null 2>&1 || die "assembler not found: $AS_BIN"
  command -v "$LD_BIN" >/dev/null 2>&1 || die "linker not found: $LD_BIN"
}

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

build_flux0_if_needed() {
  local repo_src="$ROOT_DIR/flux0.s"
  local repo_bin="$ROOT_DIR/flux0"
  local obj
  mkdir -p "$FLUX_DATA_DIR"

  if [[ -x "$FLUX_BOOTSTRAP_BIN" ]]; then
    return
  fi

  if [[ -x "$repo_bin" ]]; then
    cp "$repo_bin" "$FLUX_BOOTSTRAP_BIN"
    chmod +x "$FLUX_BOOTSTRAP_BIN"
    return
  fi

  if [[ -f "$repo_src" ]]; then
    obj="$FLUX_DATA_DIR/flux0.o"
    "$AS_BIN" --64 "$repo_src" -o "$obj"
    "$LD_BIN" -o "$FLUX_BOOTSTRAP_BIN" "$obj"
    chmod +x "$FLUX_BOOTSTRAP_BIN"
    rm -f "$obj"
    return
  fi

  die "bootstrap compiler not found. Reinstall Flux with 'make build'."
}

resolve_output_path() {
  local input="$1"
  local provided="${2:-}"
  if [[ -n "$provided" ]]; then
    printf '%s\n' "$provided"
    return
  fi
  if [[ "$input" != *.flux ]]; then
    die "input must end with .flux: $input"
  fi
  printf '%s\n' "${input%.flux}"
}

compile_flux() {
  local input="$1"
  local out_bin="$2"
  local out_dir asm_out obj_out

  [[ -f "$input" ]] || die "input file not found: $input"

  out_dir="$(dirname "$out_bin")"
  mkdir -p "$out_dir"

  asm_out="${out_bin}.s"
  obj_out="${out_bin}.o"

  "$FLUX_BOOTSTRAP_BIN" "$input" "$asm_out"
  "$AS_BIN" --64 "$asm_out" -o "$obj_out"
  "$LD_BIN" -o "$out_bin" "$obj_out"
  rm -f "$asm_out" "$obj_out"
}

parse_flux_v1() {
  local input="$1"
  local raw line current_fn="" line_no=0
  [[ -f "$input" ]] || die "input file not found: $input"

  FN_BODY=()
  ROOT_FN=""

  while IFS= read -r raw || [[ -n "$raw" ]]; do
    line_no=$((line_no + 1))
    line="${raw%%#*}"
    line="$(trim "$line")"
    [[ -z "$line" ]] && continue

    if [[ -z "$current_fn" ]]; then
      if [[ "$line" =~ ^(root|glyph)[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*\[$ ]]; then
        current_fn="${BASH_REMATCH[2]}"
        if [[ -n "${FN_BODY[$current_fn]+_}" ]]; then
          die "parse error ($input:$line_no): duplicate function '$current_fn'"
        fi
        FN_BODY["$current_fn"]=""
        if [[ "${BASH_REMATCH[1]}" == "root" ]]; then
          if [[ -n "$ROOT_FN" ]]; then
            die "parse error ($input:$line_no): only one root function is allowed"
          fi
          ROOT_FN="$current_fn"
        fi
      else
        die "parse error ($input:$line_no): expected function header 'root|glyph name ['"
      fi
    else
      if [[ "$line" == "]" ]]; then
        current_fn=""
      else
        FN_BODY["$current_fn"]+="$line"$'\n'
      fi
    fi
  done < "$input"

  if [[ -n "$current_fn" ]]; then
    die "parse error ($input): missing closing ] for function '$current_fn'"
  fi
  if [[ -z "$ROOT_FN" ]]; then
    die "parse error ($input): missing root function"
  fi
}

run_stmt() {
  local stmt="$1"
  local i n target

  if [[ "$stmt" =~ ^emit[[:space:]]+\"(([^\"\\]|\\.)*)\"[.]$ ]]; then
    printf '%b' "${BASH_REMATCH[1]}"
    return 0
  fi

  if [[ "$stmt" =~ ^line[.]$ ]]; then
    printf '\n'
    return 0
  fi

  if [[ "$stmt" =~ ^call[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)[.]$ ]]; then
    run_function "${BASH_REMATCH[1]}"
    return 0
  fi

  if [[ "$stmt" =~ ^loop[[:space:]]+([0-9]+)[[:space:]]+call[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)[.]$ ]]; then
    n="${BASH_REMATCH[1]}"
    target="${BASH_REMATCH[2]}"
    for ((i = 0; i < n; i++)); do
      run_function "$target"
      [[ "$HALT" -eq 1 ]] && return 0
    done
    return 0
  fi

  if [[ "$stmt" =~ ^done[[:space:]]+([0-9]+)[.]$ ]]; then
    EXIT_CODE="${BASH_REMATCH[1]}"
    HALT=1
    return 0
  fi

  die "runtime parse error: unknown statement '$stmt'"
}

run_function() {
  local fn="$1"
  local stmt

  [[ -n "${FN_BODY[$fn]+_}" ]] || die "runtime error: unknown function '$fn'"

  CALL_DEPTH=$((CALL_DEPTH + 1))
  if ((CALL_DEPTH > 128)); then
    die "runtime error: max call depth exceeded"
  fi

  while IFS= read -r stmt; do
    [[ -z "$stmt" ]] && continue
    run_stmt "$stmt"
    if [[ "$HALT" -eq 1 ]]; then
      break
    fi
  done <<< "${FN_BODY[$fn]}"

  CALL_DEPTH=$((CALL_DEPTH - 1))
  return 0
}

run_flux_interpreted() {
  local input="$1"
  parse_flux_v1 "$input"
  HALT=0
  EXIT_CODE=0
  CALL_DEPTH=0
  run_function "$ROOT_FN"
  return "$EXIT_CODE"
}

validate_flux_extension() {
  local input="$1"
  [[ "$input" == *.flux ]] || die "input must end with .flux: $input"
}

main() {
  [[ $# -ge 2 ]] || { usage; exit 1; }

  local cmd="$1"
  local input="$2"
  validate_flux_extension "$input"

  case "$cmd" in
    build)
      require_tools
      local output
      output="$(resolve_output_path "$input" "${3:-}")"
      build_flux0_if_needed
      compile_flux "$input" "$output"
      echo "Built $output"
      ;;
    run)
      if [[ $# -ne 2 ]]; then
        die "run accepts only: flux run <input.flux>"
      fi
      run_flux_interpreted "$input"
      ;;
    *)
      usage
      die "unknown command: $cmd"
      ;;
  esac
}

main "$@"
