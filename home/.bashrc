#
# ~/.bashrc  (managed by ~/dotfiles)
#

# PATH (works for non-interactive shells too)
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac
case ":$PATH:" in *":$HOME/.dotnet/tools:"*) ;; *) export PATH="$PATH:$HOME/.dotnet/tools" ;; esac

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# ---- Shell options ----
shopt -s checkwinsize   # re-check terminal size after each command
shopt -s expand_aliases
shopt -s histappend     # append to history instead of overwriting

# ---- Completion ----
[[ -r /usr/share/bash-completion/bash_completion ]] && . /usr/share/bash-completion/bash_completion

# ---- Window title for X terminals ----
case ${TERM} in
xterm* | rxvt* | Eterm* | aterm | kterm | gnome* | interix | konsole* | tmux* | alacritty)
	PROMPT_COMMAND='echo -ne "\033]0;${USER}@${HOSTNAME%%.*}:${PWD/#$HOME/\~}\007"'
	;;
screen*)
	PROMPT_COMMAND='echo -ne "\033_${USER}@${HOSTNAME%%.*}:${PWD/#$HOME/\~}\033\\"'
	;;
esac

# ---- Colors ----
if type -P dircolors >/dev/null; then
	if [[ -f ~/.dir_colors ]]; then
		eval "$(dircolors -b ~/.dir_colors)"
	elif [[ -f /etc/DIR_COLORS ]]; then
		eval "$(dircolors -b /etc/DIR_COLORS)"
	else
		eval "$(dircolors -b)"
	fi
fi

alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias egrep='grep -E --color=auto'
alias fgrep='grep -F --color=auto'
alias pamcan='pacman'
alias clear="printf '\033[2J\033[3J\033[1;1H'"

# Fallback prompt if starship is missing
PS1='[\u@\h \W]\$ '

# Print a table of terminal color escapes
colors() {
	local fgc bgc vals seq0

	printf "Color escapes are %s\n" '\e[${value};...;${value}m'
	printf "Values 30..37 are \e[33mforeground colors\e[m\n"
	printf "Values 40..47 are \e[43mbackground colors\e[m\n"
	printf "Value  1 gives a  \e[1mbold-faced look\e[m\n\n"

	for fgc in {30..37}; do
		for bgc in {40..47}; do
			fgc=${fgc#37} # white
			bgc=${bgc#40} # black

			vals="${fgc:+$fgc;}${bgc}"
			vals=${vals%%;}

			seq0="${vals:+\e[${vals}m}"
			printf "  %-9s" "${seq0:-(default)}"
			printf " ${seq0}TEXT\e[m"
			printf " \e[${vals:+${vals+$vals;}}1mBOLD\e[m"
		done
		echo
		echo
	done
}

# ex - archive extractor. usage: ex <file>
ex() {
	if [[ -f "$1" ]]; then
		case "$1" in
		*.tar.bz2) tar xjf "$1" ;;
		*.tar.gz) tar xzf "$1" ;;
		*.tar.xz) tar xJf "$1" ;;
		*.tar.zst) tar --zstd -xf "$1" ;;
		*.bz2) bunzip2 "$1" ;;
		*.rar) unrar x "$1" ;;
		*.gz) gunzip "$1" ;;
		*.tar) tar xf "$1" ;;
		*.tbz2) tar xjf "$1" ;;
		*.tgz) tar xzf "$1" ;;
		*.zip) unzip "$1" ;;
		*.Z) uncompress "$1" ;;
		*.7z) 7z x "$1" ;;
		*) echo "'$1' cannot be extracted via ex()" ;;
		esac
	else
		echo "'$1' is not a valid file"
	fi
}

# Mirror a website for offline use
getWeb() {
	wget --mirror --convert-links --adjust-extension --page-requisites --no-parent --no-check-certificate "$1"
}

# Django / venv helpers
alias pmc="python manage.py createsuperuser"
alias pmk="python manage.py makemigrations"
alias pmm="python manage.py migrate"
alias pmr="python manage.py runserver"
alias acenv="source ./env/bin/activate"

# ---- Tools ----
[[ -r /usr/share/nvm/init-nvm.sh ]] && source /usr/share/nvm/init-nvm.sh

# yt-dlp shortcuts
[[ -f ~/.config/bash/yt-dlp.sh ]] && source ~/.config/bash/yt-dlp.sh

# Prompt (keep last so it wraps PROMPT_COMMAND)
command -v starship >/dev/null && eval "$(starship init bash)"
