#!/usr/bin/env zsh
# shellcheck disable=SC2086
# shellcheck disable=SC2154
# shellcheck disable=SC2016
# shellcheck disable=SC2296

# Update module status via: __dotfiles_module_set FIELD VALUE
# Log relevant stdout and stderr output via: __dotfiles_(log|err) YAML_VALUE

__dotfiles_register_module fzf

__dotfiles_brew_register fzf

_fzf() {
	local spath="${PWD}"
	local pattern="."
	if [[ $# -eq 2 ]]; then
		spath="${2}"
	fi
	if [[ $# -gt 0 ]]; then
		pattern="${1}"
	fi

	export FD_IGNORE_PATHS=(.git .idea .venv zinit AppSupport)
	export FZF_DEFAULT_COMMAND="fd --type f -H -E ${(j: -E :)FD_IGNORE_PATHS} -L -- '${pattern}' '${spath}'"
	#export FZF_DEFAULT_COMMAND="fd --type f -H -L"
	export FZF_DEFAULT_OPTS="--preview='bat --color=always {}' --preview-window='~3' --bind=ctrl-j:preview-down --bind=ctrl-k:preview-up"
	export FZF_DEFAULT_OPTS=$FZF_DEFAULT_OPTS'
	--color=fg:#d0d0d0,fg+:#d0d0d0,bg:#121212,bg+:#262626
	--color=hl:#5f87af,hl+:#5fd7ff,info:#afaf87,marker:#87ff00
	--color=prompt:#d7005f,spinner:#af5fff,pointer:#af5fff,header:#87afaf
	--color=border:#262626,label:#aeaeae,query:#d9d9d9
	--border="rounded" --border-label="" --preview-window="border-rounded" --prompt="> "
	--marker=">" --pointer="◆" --separator="─" --scrollbar="│"'

	/opt/homebrew/bin/fzf
}

__dotfiles_configure_fzf() {
	/opt/homebrew/bin/fzf --zsh
	echo alias fzf=_fzf
}

__dotfiles_setup_fzf_env() {
	if [[ $(__dotfiles_module_get configured) != "true" ]]; then
		__dotfiles_module_set configured true
	fi
}
