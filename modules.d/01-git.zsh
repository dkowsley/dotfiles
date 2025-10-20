#!/usr/bin/env zsh
# shellcheck disable=SC2086
# shellcheck disable=SC2154
# shellcheck disable=SC2016
# shellcheck disable=SC2296

# Update module status via: __dotfiles_module git FIELD VALUE
# Log relevant stdout and stderr output via: __dotfiles_log git YAML_VALUE ["err"]

__dotfiles_register_module git

__dotfiles_git_helper_tools() {
  __dotfiles_brew_install gh git-delta homebrew/cask/kdiff3:cask
}

alias _gcg='git config --global'
__dotfiles_configure_git() {
  local failure=0
  for f in USERNAME EMAIL; do
    if [[ ! -v "GIT_${f}" ]]; then
      failure=1
      __dotfiles_err "GIT_${f} missing from environment variables. Please set it to your name."
    fi
  done

  if [[ $failure -eq 1 ]]; then
    return 1
  fi

  _gcg user.name "${GIT_USERNAME}"
  _gcg user.email "${GIT_EMAIL}"
  _gcg alias.co checkout
  _gcg alias.cb "checkout -b"
  _gcg alias.br branch
  _gcg alias.cassm "commit -asSem"
  _gcg alias.casm "commit -asem"
  _gcg alias.dp "diff"
  _gcg alias.dps "diff --staged"
  _gcg alias.dpm "diff origin/main"
  _gcg alias.dpms "diff origin/main --staged"
  _gcg alias.st status
  _gcg alias.hist "log --pretty=format:'%h %ad | %s%d [%an]' --graph --date=short"
  _gcg core.pager delta
  _gcg interactive.diffFilter 'delta --color-only'
  _gcg delta.navigate true
  _gcg merge.conflictStyle zdiff3

  unalias _gcg

  for al in $(git --list-cmds=alias); do
    alias g$al="git $al"
  done
}

__dotfiles_setup_git_env() {
  __dotfiles_git_helper_tools
  if [[ $(__dotfiles_module_get configured) != "true" ]]; then
    __dotfiles_configure_git
    __dotfiles_module_set configured true
  fi
}

__dotfiles_setup_git_env

__dotfiles_finish_module git