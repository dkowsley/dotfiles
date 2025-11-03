#!/usr/bin/env zsh

if [[ $# -ne 2 ]]; then
	echo "Usage: ${0} MODULE_NAME PRIORITY"
fi

cd "$(realpath "$(dirname "${0}")")" || exit 1

mod_file_path="$(printf "modules.d/%02d-%s.zsh" "${2}" "${1}")"

MODULE="${1}" envsubst < skeleton.zsh > "${mod_file_path}"
chmod +x "${mod_file_path}"
