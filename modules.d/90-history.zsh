#!/usr/bin/env zsh
# shellcheck disable=SC2086
# shellcheck disable=SC2154
# shellcheck disable=SC2016
# shellcheck disable=SC2296

__dotfiles_register_module history

export HISTFILE=$HOME/.zsh_history
export HISTSIZE=5000000
export SAVEHIST=$HISTSIZE

setopt EXTENDED_HISTORY          # Write the history file in the ':start:elapsed;command' format.
setopt INC_APPEND_HISTORY_TIME   # Write to the history file immediately after command returns, not when the shell exits.
#setopt SHARE_HISTORY             # Share history between all sessions.
setopt HIST_EXPIRE_DUPS_FIRST    # Expire a duplicate event first when trimming history.
setopt HIST_IGNORE_DUPS          # Do not record an event that was just recorded again.
setopt HIST_IGNORE_ALL_DUPS      # Delete an old recorded event if a new event is a duplicate.
setopt HIST_FIND_NO_DUPS         # Do not display a previously found event.
#setopt HIST_IGNORE_SPACE         # Do not record an event starting with a space.
setopt HIST_SAVE_NO_DUPS         # Do not write a duplicate event to the history file.
setopt HIST_VERIFY               # Do not execute immediately upon history expansion.
setopt APPEND_HISTORY            # append to history file
setopt HIST_NO_STORE             # Don't store history commands
setopt HIST_REDUCE_BLANKS        # Strip superfluous blanks

alias sync_hist='fc -RI'

__dotfiles_configure_history() {
	echo -n
}

__dotfiles_setup_history_env() {
	if [[ $(__dotfiles_module_get configured) != "true" ]]; then
		__dotfiles_module_set configured true
	fi
}
