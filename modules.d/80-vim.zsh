#!/usr/bin/env zsh
# shellcheck disable=SC2086
# shellcheck disable=SC2154
# shellcheck disable=SC2016
# shellcheck disable=SC2296

# Update module status via: __dotfiles_module_set FIELD VALUE
# Log relevant stdout and stderr output via: __dotfiles_(log|err) YAML_VALUE

__dotfiles_register_module vim

__dotfiles_brew_register fzf

__dotfiles_configure_vim() {
	cat <<-VIMRC > "${HOME}/.vimrc"
	syntax on               " enable syntax highlighting
	set cursorline          " highlight the current line
	" set background=dark   " darker color scheme
	" set ruler             " show line number in bar
	set nobackup            " don't create pointless backup files; Use VCS instead
	set autoread            " watch for file changes
	set number              " show line numbers
	set showcmd             " show selection metadata
	set showmode            " show INSERT, VISUAL, etc. mode
	set showmatch           " show matching brackets
	set autoindent smartindent  " auto/smart indent
	set smarttab            " better backspace and tab functionality
	set scrolloff=5         " show at least 5 lines above/below
	filetype on             " enable filetype detection
	filetype indent on      " enable filetype-specific indenting
	filetype plugin on      " enable filetype-specific plugins
	" colorscheme cobalt      " requires cobalt.vim to be in ~/.vim/colors

	" column-width visual indication
	let &colorcolumn=join(range(143,999),",")
	highlight ColorColumn ctermbg=235 guibg=#001D2F

	" tabs and indenting
	set autoindent          " auto indenting
	set smartindent         " smart indenting
	set expandtab           " spaces instead of tabs
	set tabstop=2           " 2 spaces for tabs
	set shiftwidth=2        " 2 spaces for indentation

	" bells
	set noerrorbells        " turn off audio bell
	set visualbell          " but leave on a visual bell

	" search
	set hlsearch            " highlighted search results
	set showmatch           " show matching bracket

	" other
	set guioptions=aAace    " don't show scrollbar in MacVim
	" call pathogen#infect()  " use pathogen

	" clipboard
	set clipboard=unnamed   " allow yy, etc. to interact with OS X clipboard

	" shortcuts
	map <F2> :NERDTreeToggle<CR>

	" remapped keys
	inoremap {      {}<Left>
	inoremap {<CR>  {<CR>}<Esc>O
	inoremap {{     {
	inoremap {}     {}

	set rtp+=/opt/homebrew/opt/fzf
	VIMRC
}

__dotfiles_setup_vim_env() {
	if [[ $(__dotfiles_module_get configured) != "true" ]]; then
		__dotfiles_with_lock __dotfiles_configure_vim
		__dotfiles_module_set configured true
	fi
}
