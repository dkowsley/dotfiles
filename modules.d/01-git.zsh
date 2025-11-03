#!/usr/bin/env zsh
# shellcheck disable=SC2016
# shellcheck disable=SC2086
# shellcheck disable=SC2154
# shellcheck disable=SC2155
# shellcheck disable=SC2296

# Update module status via: __dotfiles_module git FIELD VALUE
# Log relevant stdout and stderr output via: __dotfiles_log git YAML_VALUE ["err"]

__dotfiles_register_module git

__dotfiles_brew_register gh gnupg git-delta homebrew/cask/kdiff3:cask

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

	while IFS= read -r line; do
		echo unalias $line
	done < <(alias | grep -E "^g[a-z]+=['\"]?git" | cut -d'=' -f1)

	if [[ -v GIT_GPG_KEY ]]; then
		if ! gpg --list-secret-keys --keyid-format=long | grep -q "${GIT_GPG_KEY}"; then
			__dotfiles_err "\$GIT_GPG_KEY (${GIT_GPG_KEY}) not found in: gpg --list-secret-keys --keyid-format=long"
		else
			git config --global --unset gpg.format
			git config --global user.signingkey "${GIT_GPG_KEY}!"
			git config --global commit.gpgsign true
			git config --global tag.gpgSign true
			local rc_file="${HOME}/$([ -r ~/.zshrc ] && echo .zshrc || echo .zprofile)"
			if ! grep -q 'export GPG_TTY=$(tty)' "${rc_file}"; then
				(
					echo
					echo 'export GPG_TTY=$(tty)'
					echo
				) >> "${rc_file}"
			fi
		fi
	fi

	git config --global alias.cg "config --global"
	git cg alias.a add
	git cg alias.c commit
	git cg alias.co checkout
	git cg alias.cb "checkout -b"
	git cg alias.br branch
	git cg alias.ca "commit -a"
	git cg alias.cam "commit -am"
	git cg alias.casm "commit -asem"
	git cg alias.cassm "commit -S -asem"
	git cg alias.csm "commit -sem"
	git cg alias.cssm "commit -S -sem"
	git cg alias.cm "commit -m"
	git cg alias.current "rev-parse --abbrev-ref HEAD"
	git cg alias.d "diff"
	git cg alias.dc "diff --cached"
	git cg alias.ds "diff --staged"
	git cg alias.dm "diff origin/main"
	git cg alias.dms "diff origin/main --staged"
	git cg alias.hist "log --pretty=format:'%h %ad | %s%d [%an]' --graph --date=short"
	git cg alias.l 'log --graph --pretty=format:"%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset" --abbrev-commit'
	git cg alias.p push
	git cg alias.s status

	git cg interactive.diffFilter "delta --color-only"
	git cg delta.navigate true
	git cg merge.conflictStyle zdiff3

	git cg core.pager delta
	git cg core.editor vim
	git cg core.excludesfile ~/.gitignore
	git cg core.autocrlf input
	git cg color.branch auto
	git cg color.diff auto
	git cg color.interactive auto
	git cg color.status auto

	git cg init.defaultBranch main
	git cg web.browser google-chrome
	git cg credential.helper osxkeychain
	git cg push.default simple
	git cg merge.tool kdiff3
	git cg difftool.prompt false

	git cg pull.rebase true
	git cg push.autoSetupRemote true # Equal to `git push --set-upstream origin $(git rev-parse --abbrev-ref HEAD)` if new
	git cg push.default simple
	git cg rebase.autoStash true

	git cg user.name "${GIT_USERNAME}"
	git cg user.email "${GIT_EMAIL}"

	while IFS= read -r line; do
		local alias_name=$(echo "${line}" | sed -E 's|alias\.([^ ]+) (.+)|\1|g')
			local alias_cmd=$(echo "${line}" | sed -E 's|alias\.([^ ]+) (.+)|\2|g')
			local str_wrap_char="'"
			if [[ "${alias_cmd}" == *\'* ]]; then
				str_wrap_char='"'
		fi
		echo "alias g${alias_name}=${str_wrap_char}git ${alias_cmd}${str_wrap_char}"
	done < <(git config --get-regexp ^alias\\.)
}

__dotfiles_setup_git_env() {
	if [[ $(__dotfiles_module_get configured) != "true" ]]; then
		__dotfiles_with_lock __dotfiles_configure_git
		__dotfiles_module_set configured true
	fi
}
