#!/usr/bin/env zsh
# shellcheck disable=SC2154
# shellcheck disable=SC2016
# shellcheck disable=SC2296
# shellcheck disable=SC1090
# shellcheck disable=SC2155

loader_start=$(date +'%s.%N')

# Will set brew installed gnu utils in front of path, overriding POSIX variants.
export __DOTFILES_ORIG_PWD="${PWD}"
export __DOTFILES_INSTALL_GNU_BINARIES_AS_OVERRIDES=1
export DEBUG_DOTFILES=${DEBUG_DOTFILES:-/dev/null}
export __DOTFILES_ORIG_PATH="${PATH}"
export __DOTFILES_ROOT="$(realpath "$(dirname "${0}")")"
export __DOTFILES_PATHS_REGISTRY="${__DOTFILES_PATHS_REGISTRY:-$(mktemp /tmp/dotfiles.paths.yaml.XXXXXX)}"
export __DOTFILES_STATUS="${__DOTFILES_STATUS:-$(mktemp /tmp/dotfiles.status.yaml.XXXXXX)}"
export __DOTFILES_LOG="${__DOTFILES_LOG:-$(mktemp /tmp/dotfiles.log.yaml.XXXXXX)}"
export __DOTFILES_ERR_LOG="${__DOTFILES_ERR_LOG:-$(mktemp /tmp/dotfiles.err.yaml.XXXXXX)}"
export __DOTFILES_ACTIVE_MODULE=loader
export __DOTFILES_MODULE_STACK=("${__DOTFILES_ACTIVE_MODULE}")
export __DOTFILES_FLOCK_LIST=()
export __DOTFILES_BREW_PACKAGES=()

#set -x

__dotfiles_error() {
  echo "${funcsourcetrace[1]}:${functrace[1]}: ${1}" >> /dev/stderr
}

__dotfiles_handle_error() {
    local exit_status=$?
    (
      if [[ ${exit_status} -ne 0 ]]; then
#        printf "${(j|\n|)funcfiletrace[*]}" > /dev/stderr
        fftrace="${(j|@@|)funcfiletrace[*]}" ec="${exit_status}" args="${*}" yq -n -PI2 '
          [{
            "log": "Unhandled error occurred",
            "exit_code": env(ec),
            "args": strenv(args),
            "last_module": {
            	"name": strenv(__DOTFILES_ACTIVE_MODULE),
            	"output": load(strenv(__DOTFILES_LOG)).modules[strenv(__DOTFILES_ACTIVE_MODULE)]
			},
            "stack_trace": strenv(fftrace) | split("@@")
          }]'
      fi
    ) >> "${__DOTFILES_ERR_LOG}"
    cp "${__DOTFILES_ERR_LOG}" /tmp/dotfiles.err.last.yaml
    set +x
#    yq '.' "${__DOTFILES_ERR_LOG}"
#    read -sk "Error occurred. Shell exiting. Press any key to continue..."
    return "${exit_status}"
}
#trap '__dotfiles_handle_error' ZERR EXIT SIGTERM

#TRAPEXIT() {
#  __dotfiles_handle_error "${@}" || true
#}

# Ensure required packages are present
__dotfiles_brew_install() {
  local last_run="$(head -n 1 "${lock_file}")"
#  read -ru 8 last_run
  if [[ -n $last_run ]]; then
    local since_last_run=$(( $(date +'%s.%N') - last_run ))
    if [[ $since_last_run -lt 10 ]]; then
      printf "($$) Brew: install ran recently (%.2fs ago). Skipping.\n" $since_last_run >> "${lock_file}"
      return 0
    fi
  fi

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
      echo "Brew: got ${cmd} for ${name}"
      if [[ "${cmd}" == "install" ]]; then
        brew install "${args[@]}"
      else
        brew upgrade "${args[@]}"
      fi
    fi
  done
  date +'%s.%N' > "${lock_file}"
}

__dotfiles_obtain_lock() {
  flock -w 20 "${1}"
  __DOTFILES_FLOCK_LIST+=("${1}")
}

__dotfiles_release_locks() {
  for f in "${__DOTFILES_FLOCK_LIST[@]}"; do
    flock -u "${f}"
  done
}

__dotfiles_with_lock() {
  local start_time=$(date +'%s.%N')
  local lock_time=$(mktemp)
  export lock_file="/tmp/${1}"
  (
#    echo -n "Obtaining ${1} lock at ${start_time} ... " >&2
    flock -w 120 8
    date +'%s.%N' > "${lock_time}"
#    printf "obtained (waited %.2fs)\n" "$(( $(cat "${lock_time}") - start_time ))" >&2
    "${@}"
#    echo -n "Releasing ${1} lock at $(date +'%s.%N') ... " >&2
  ) 8>> "${lock_file}"
  unset lock_file
#  printf "released (ran %.3fs)\n" "$(( $(date +'%s.%N') - $(cat "${lock_time}") ))" >&2
}

__dotfiles_brew_register() {
  # shellcheck disable=SC2206
  __DOTFILES_BREW_PACKAGES+=(${*})
}

__dotfiles_brew_reconcile() {
  # shellcheck disable=SC2048
  # shellcheck disable=SC2086
  __dotfiles_with_lock __dotfiles_brew_install ${__DOTFILES_BREW_PACKAGES[*]}
}

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
		  ) * (.paths // {}),
		  "orig_paths": $orig_paths
		} | .paths[strenv(new_path)] |= (env(priority)) |
		.paths = (.paths | sort_by(.))
		' "${__DOTFILES_PATHS_REGISTRY}"
}

__dotfiles_render_path() {
  yq '.paths | sort_by(.paths[key]) | keys | join(":")' "${__DOTFILES_PATHS_REGISTRY}"
}

__dotfiles_update_module() {
  for yqt in "${__DOTFILES_STATUS}" "${__DOTFILES_LOG}"; do
    if [[ ! -f "${yqt}" ]]; then
      touch "${yqt}"
      yq -iPI2 '{"modules": {}}' "${yqt}"
    fi
  done

  if [[ ! $# -ge 4 ]]; then
    __dotfiles_error "Missing required arguments: __config_update_module __DOTFILES_STATUS|__DOTFILES_LOG MODULE FIELD VALUE"
    return 1
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
  __dotfiles_update_module "${log_type:-status}" "${__DOTFILES_ACTIVE_MODULE}" "${1}" "${2}"
}

__dotfiles_module_get() {
  if [[ $# -ne 1 ]]; then
    __dotfiles_error "Missing required argument: __dotfiles_module_get FIELD"
  fi
  mod="${__DOTFILES_ACTIVE_MODULE}" field="${1}" yq '.[strenv(mod)][strenv(field)]' "${__DOTFILES_STATUS}"
}

__dotfiles_register_module() {
  local YQ_OVERRIDE='.modules *= {(strenv(module)): {"start_time": now, "stdout": [], "stderr": []}}'
  YQ_OVERRIDE="${YQ_OVERRIDE}" __dotfiles_update_module log "${__DOTFILES_ACTIVE_MODULE}" start ""
  local YQ_OVERRIDE='.modules *= {(strenv(module)): {"start_time": now, "configured": .modules[strenv(mod)].configured // false}}'
  YQ_OVERRIDE="${YQ_OVERRIDE}" __dotfiles_update_module status "${__DOTFILES_ACTIVE_MODULE}" configured ""
}

__dotfiles_finish_module() {
  log_type=log __dotfiles_module_set log "result" '{"finish_time": now, "failed": $mod.stderr | any}'
  __dotfiles_module_set status "finish_time" '{"finish_time": now, "failed": $mod.stderr | any}'
}

__dotfiles_source() {
  local module_name="$(basename "${1}" | cut -d'.' -f1 | cut -d'-' -f2-)"
  __DOTFILES_MODULE_STACK=("${module_name}" "${__DOTFILES_MODULE_STACK[@]}")
  export __DOTFILES_ACTIVE_MODULE="${module_name}"
  source "${1}"
  shift __DOTFILES_MODULE_STACK
  export __DOTFILES_ACTIVE_MODULE="${__DOTFILES_MODULE_STACK[1]}"
}

resource() {
	echo -n > /tmp/resource.log
#	__resource_trapper() {
#		(
#			echo "----------- Trapped failure on resource -----------"
#			echo "${(j:\n:)funcfiletrace[*]}"
#		) >> /tmp/resource.log
#	}
#	trap '__resource_trapper' ZERR EXIT SIGTERM
	source "${HOME}/.zshrc" &>/tmp/resource.log
	cat /tmp/resource.log
}

__dotfiles_brew_register flock yq fzf eza ripgrep "${__gnu_utils[@]}"

[[ -f "${__DOTFILES_PATHS_REGISTRY}" ]] || touch "${__DOTFILES_PATHS_REGISTRY}"

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

__gnu_utils=(gnu-sed coreutils)
__dotfiles_with_lock __dotfiles_brew_reconcile

__dotfiles_register_module

for package in "${__gnu_installs[@]}"; do
  if [[ $__DOTFILES_INSTALL_GNU_BINARIES_AS_OVERRIDES -eq 1 ]]; then
    __dotfiles_add_path "$(brew --prefix "${package}")/libexec/gnubin" 1
  fi
done

source logger.zsh

for dotfile in modules.d/*.zsh; do
  __dotfiles_source "${dotfile}"
done

for mod in $(yq '.modules | keys | join(" ")' "${__DOTFILES_STATUS}"); do
  if [[ "${mod}" != "loader" ]]; then
    old_mod=$__DOTFILES_ACTIVE_MODULE
    export __DOTFILES_ACTIVE_MODULE=$mod
    echo "Running phase 1 eval on ${mod}" >"${DEBUG_DOTFILES}"
    additional_eval=$(eval "__dotfiles_setup_${mod}_env")
    if [[ -n "${additional_eval}" ]]; then
		echo "Running phase 2 eval on ${mod}" >"${DEBUG_DOTFILES}"
		eval "${additional_eval}" || (
      		printf "Failed to eval mod '%s' with:\ncat <<ZSH\n%s\nZSH\n" "${mod}" "${additional_eval}" >"${DEBUG_DOTFILES}"
		)
    fi
    export __DOTFILES_ACTIVE_MODULE=$old_mod
  fi
done

export PATH="$(__dotfiles_render_path)"
__dotfiles_finish_module
__dotfiles_release_locks
unset DEBUG_DOTFILES
trap '' ZERR EXIT SIGTERM

cd "${__DOTFILES_ORIG_PWD}"

#printf "Dotfiles finished loading in %.2fs\n" $(( $(date +'%s.%N') - loader_start ))

set +ex
