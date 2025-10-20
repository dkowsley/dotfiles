#!/usr/bin/env zsh
# shellcheck disable=SC2154
# shellcheck disable=SC2016
# shellcheck disable=SC2296
# shellcheck disable=SC1090
# shellcheck disable=SC2155

# Will set brew installed gnu utils in front of path, overriding POSIX variants.
export __DOTFILES_INSTALL_GNU_BINARIES_AS_OVERRIDES=1

__dotfiles_error() {
  echo "${funcsourcetrace[1]}:${functrace[1]}: ${1}" >> /dev/stderr
}

__dotfiles_handle_error() {
    local exit_status=$?
    (
      if [[ ${exit_status} -ne 0 ]]; then
        echo "Unhandled error occurred with exit status ${exit_status}"
        fftrace="${(j|@@|)funcfiletrace[*]}" msg="${*}" yq -n '
          {
            "last_module": load(strenv(__DOTFILES_LOG)).modules[strenv(__DOTFILES_ACTIVE_MODULE)],
            "stack_trace": strenv(fftrace) | split("@@"),
            "msg": strenv(msg)
          }'
      fi
    ) > /tmp/dotfiles.err.log
    set +x
    return "${exit_status}"
}
trap '__dotfiles_handle_error' ZERR EXIT SIGTERM

TRAPEXIT() {
  __dotfiles_handle_error "${@}"
}

set -eo pipefail

export DEBUG_DOTFILES=${DEBUG_DOTFILES:-/dev/null}
export __DOTFILES_PATHS_REGISTRY="${HOME}/.dotfiles_paths.yaml"
export __DOTFILES_ORIG_PATH="${PATH}"
export __DOTFILES_ROOT="$(realpath "$(dirname "${0}")")"
export __DOTFILES_STATUS="${HOME}/.dotfiles_status.yaml"
export __DOTFILES_LOG="${HOME}/.dotfiles_log.yaml"
export __DOTFILES_MODULE_STACK=()
export __DOTFILES_ACTIVE_MODULE=loader

rm "${__DOTFILES_LOG}"
for f in "${__DOTFILES_PATHS_REGISTRY}" "${__DOTFILES_STATUS}" "${__DOTFILES_LOG}"; do
  [[ -f "${f}" ]] || touch "${f}"
done

if ! cd "${__DOTFILES_ROOT}"; then
  echo "Failed to cd to '${__DOTFILES_ROOT}' when loading dotfiles" >> /dev/stderr
  return 1
fi

# Install homebrew if not installed
if ! command -v brew &>/dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Load homebrew into shell
eval "$(/opt/homebrew/bin/brew shellenv)"
# Tell homebrew to not autoupdate every single time I run it (just once a week).
export HOMEBREW_AUTO_UPDATE_SECS=604800

# Ensure required packages are present
__dotfiles_brew_install() {
  local brew_installs="$(
    brew info --json=v2 $(brew list) 2>/dev/null |
      args="${(j|@@|)*}" yq -PI2 '
        .input = (
          strenv(args) | split("@@") |
          map(
            . | split(":") |
            {
              "key": .[0],
              "value": {
                "cask": (.[1] // false) == "cask",
                "outdated": false,
                "command": "install"
              }
            }
          ) | from_entries
        ) |
        .casks = (
          .casks |
            map({
              "key": "\(.tap)/\(.token)",
              "value": {
                "cask": true,
                "outdated": .outdated,
                "command": "skip"
              }
            }) | from_entries
        ) |
        .formulae = (
          .formulae |
            map({
              "key": .name,
              "value": {
                "cask": false,
                "outdated": .outdated,
                "command": "skip"
              }
            }) | from_entries
        ) |
        .input *= .formulae |
        .input *= .casks |
        .input |
        with_entries(
          select(.value.outdated).value.command = "upgrade"
        )'
    )"
  for package in "${@}"; do
    local name="$(echo "${package}" | cut -d':' -f1)"
    local cmd="$(echo "${brew_installs}" | name="${name}" yq '.[strenv(name)].command')"
    if [[ "${cmd}" != "skip" ]]; then
      local args=("${name}")
      [[ "$(echo "${package}" | cut -d':' -f2)" == "cask" ]] && args+=(--cask)
      if [[ "${cmd}" == "install" ]]; then
        brew install "${args[@]}"
      else
        brew upgrade "${args[@]}"
      fi
    fi
  done
}

__gnu_utils=(gnu-sed coreutils)
__dotfiles_brew_install yq fzf eza "${__gnu_utils[@]}"

__dotfiles_add_path() {
  touch "${__DOTFILES_PATHS_REGISTRY}"
  new_path="${1}" priority="${2}" yq -iPI2 '
    (
      strenv(__DOTFILES_ORIG_PATH) | split(":")
    ) as $orig_paths |
    {
      "paths": (
        $orig_paths | keys |
        map({
          "key": $orig_paths[.],
          "value": 500 + .
        }) | from_entries
      ),
      "orig_paths": $orig_paths
    } | .paths[strenv(new_path)] |= (env(priority))
    ' "${__DOTFILES_PATHS_REGISTRY}"
}

__dotfiles_render_path() {
  yq '.paths | sort_by(.paths[key]) | keys | join(":")' "${__DOTFILES_PATHS_REGISTRY}"
}

for package in "${__gnu_installs[@]}"; do
  if [[ $__DOTFILES_INSTALL_GNU_BINARIES_AS_OVERRIDES -eq 1 ]]; then
    __dotfiles_add_path "$(brew --prefix "${package}")/libexec/gnubin" 1
  fi
done

__dotfiles_update_module() {
  if [[ ! $# -ge 4 ]]; then
    __dotfiles_error "Missing required arguments: __config_update_module __DOTFILES_STATUS|__DOTFILES_LOG MODULE FIELD VALUE"
    return 1
  fi

  if [[ ! -f "${1}" ]]; then
    touch "${1}"
    dir=$(dirname "${1}") yq -i '{"dir": strenv(dir), "modules": {}}' "${1}"
  fi

  local yq_target
  local yq_expression
  if [[ "${1}" == "status" ]]; then
    yq_target="${__DOTFILES_STATUS}"
    yq_expression="
        .modules *= {
          (strenv(module)): {
            (strenv(field)): env(value)
          }
        }
        "
  elif [[ "${1}" == "log" ]]; then
    yq_target="${__DOTFILES_LOG}"
    yq_expression=".modules[strenv(module)][strenv(field)] += [env(value)]"
  else
    __dotfiles_error "${1} is not a valid target for '__dotfiles_update_module'" > /dev/stderr
    return 1
  fi

  module="${2}" field="${3}" value="${4}" yq -iPI2 "${YQ_OVERRIDE:-$yq_expression}" "${yq_target}"
}

__dotfiles_module_set() {
  if [[ $# -lt 2 ]]; then
    __dotfiles_error "Missing required argument: __dotfiles_module_set FIELD VALUE"
  fi
  __dotfiles_update_module status "${__DOTFILES_ACTIVE_MODULE}" "${1}" "${2}"
}

__dotfiles_module_get() {
  if [[ $# -ne 1 ]]; then
    __dotfiles_error "Missing required argument: __dotfiles_module_get FIELD"
  fi
  mod="${__DOTFILES_ACTIVE_MODULE}" field="${1}" yq '.[strenv(mod)][strenv(field)]' "${__DOTFILES_STATUS}"
}

__dotfiles_register_module() {
  local YQ_OVERRIDE='.modules *= {(strenv(module)): {"start_time": now, "stdout": [], "stderr": []}}'
  YQ_OVERRIDE="${YQ_OVERRIDE}" __dotfiles_update_module log "${1}" start ""
}

__dotfiles_finish_module() {
  local YQ_OVERRIDE='.modules[strenv(module)] as $mod | $mod *= {"finish_time": now, "failed": $mod.stderr | any}'
  YQ_OVERRIDE="${YQ_OVERRIDE}" __dotfiles_update_module log "${1}" "" "${2}"
}

__dotfiles_source() {
  local module_name="$(basename "${1}" | cut -d'.' -f1 | cut -d'-' -f2-)"
  __DOTFILES_MODULE_STACK=("${module_name}" "${__DOTFILES_MODULE_STACK[@]}")
  export __DOTFILES_ACTIVE_MODULE="${module_name}"
  source "${1}"
  shift __DOTFILES_MODULE_STACK
  export __DOTFILES_ACTIVE_MODULE="${__DOTFILES_MODULE_STACK[1]}"
}

source logger.zsh

__dotfiles_register_module loader

for dotfile in modules.d/*.zsh; do
  __dotfiles_source "${dotfile}"
done

export PATH="$(__dotfiles_render_path)"

__dotfiles_finish_module loader
unset DEBUG_DOTFILES
trap '' ZERR EXIT SIGTERM
set +ex
