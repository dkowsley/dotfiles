#!/usr/bin/env zsh
# shellcheck disable=SC2086
# shellcheck disable=SC2154
# shellcheck disable=SC2016
# shellcheck disable=SC2296

# Update module status via: __dotfiles_module_set FIELD VALUE
# Log relevant stdout and stderr output via: __dotfiles_(log|err) YAML_VALUE

__dotfiles_register_module mise

__dotfiles_brew_register mise

__dotfiles_configure_mise() {
  	mise activate zsh
#  	__dotfiles_add_path "${HOME}/.local/share/mise/shims" 10
}

__dotfiles_setup_mise_env() {
	if [[ $(__dotfiles_module_get configured) != "true" ]]; then
		__dotfiles_configure_mise
		__dotfiles_module_set configured true
	fi
}
