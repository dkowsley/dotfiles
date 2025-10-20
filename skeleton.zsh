#!/usr/bin/env zsh
# shellcheck disable=SC2086
# shellcheck disable=SC2154
# shellcheck disable=SC2016
# shellcheck disable=SC2296

# Update module status via: __dotfiles_module_set FIELD VALUE
# Log relevant stdout and stderr output via: __dotfiles_(log|err) YAML_VALUE

__dotfiles_register_module ${MODULE}

__dotfiles_${MODULE}_helper_tools() {
  # __dotfiles_brew_install
  return 0
}

__dotfiles_configure_${MODULE}() {
  # Break into smaller functions, as needed, and call them here
  return 0
}

__dotfiles_setup_${MODULE}_env() {
  __dotfiles_${MODULE}_helper_tools
  if [[ $(__dotfiles_module_get configured) != "true" ]]; then
    __configure_${MODULE}
    __dotfiles_module_set configured true
  fi
}

__dotfiles_setup_${MODULE}_env

__dotfiles_finish_module ${MODULE}