#!/usr/bin/env zsh
# shellcheck disable=SC2154
# shellcheck disable=SC2016
# shellcheck disable=SC2296

__dotfiles_log_file() {
	echo /tmp/dotfiles.${__DOTFILES_ACTIVE_MODULE}.${1}.log
}

__dotfiles_err() {
	__dotfiles_update_module log "${__DOTFILES_ACTIVE_MODULE}" stderr "${@}"
}

__dotfiles_log() {
	__dotfiles_update_module log "${__DOTFILES_ACTIVE_MODULE}" stdout "${@}"
}

__dotfiles_run_log() {
	local err_log=$(__dotfiles_log_file err)
	local out_log=$(__dotfiles_log_file out)
	set +e
	eval "${@}" >"${out_log}" 2>"${err_log}"
	local exit_code=$?
	set -e
	if [[ $exit_code -eq 0 ]]; then
		__dotfiles_log "$(__dotfiles_format_ok "${(j|@@|)@}" "${out_log}" "${err_log}")"
	else
		__dotfiles_err "$(__dotfiles_format_err "${(j|@@|)@}" "${exit_code}" "${out_log}" "${err_log}")"
	fi
	rm "${out_log}" "${err_log}"
	return $exit_code
}

__dotfiles_format_err() {
	cmd="${1}" code="${2}" log="${3}" err="${4}" ftrace="${(j|,|)functrace[*]}" fileftrace="${(j|,|)funcfiletrace}" yq -nPI2 '
		(
			strenv(ftrace) |
			split(",") |
			.[1:] | # Drop the current location
			[
				.[] | split(":") |
				{
					"caller": {
						(.[0]): .[1] | to_number
					}
				}
			]
		) as $ftrace |
		(
			strenv(fileftrace) |
			split(",") |
			.[:-1] | # Drop the top-level file
			[
				.[] | split(":") |
				{
					(.[0]): {
						"line": .[1] | to_number
					}
				}
			]
		) as $fileftrace |
		strenv(cmd) | split("@@") |
		{
			"command": .[0],
			"args": .[1:] // [],
			"exit_code": env(code),
			"stdout": ([strenv(log)] | with(.[] | select(test("/tmp/dotfiles\.[^.]+\.out\.log$")); . = load_str(.)) | .[]),
			"stderr": ([strenv(err)] | with(.[] | select(test("/tmp/dotfiles\.[^.]+\.err\.log$")); . = load_str(.)) | .[]),
			"trace": (
				[
					$fileftrace | keys[] |
					$ftrace[.] as $func_line |
					$fileftrace[.] |
					with_entries(.value *= $func_line)
				]
			)
		}'
}

__dotfiles_format_ok() {
	cmd="${1}" log="${2}" err="${3}" yq -nPI2 '
		strenv(cmd) | split("@@") |
		{
			"command": .[0],
			"args": .[1:] // [],
			"stdout": ([strenv(log)] | with(.[] | select(test("/tmp/dotfiles\.[^.]+\.out\.log$")); . = load_str(.)) | .[]),
			"stderr": ([strenv(err)] | with(.[] | select(test("/tmp/dotfiles\.[^.]+\.err\.log$")); . = load_str(.)) | .[]),
		}'
}