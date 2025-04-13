colorscript random
fm6000 -r -c random

if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

export ZSH="/home/amir/.oh-my-zsh"
export BAT_THEME="Dracula"
export PATH=/home/amir/.local/bin:/home/amir/Rider/bin:/home/amir/CLion/bin:/home/amir/.yarn/bin:$PATH

ZSH_THEME="dracula"
# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" "jnrowe" "dracula" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to automatically update without prompting.
DISABLE_UPDATE_PROMPT="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

plugins=(git)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
    export EDITOR='nano'
else
    export EDITOR='nano'
fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

alias pmc="python manage.py createsuperuser"
alias pmk="python manage.py makemigrations"
alias pmm="python manage.py migrate"
alias pmr="python manage.py runserver"
alias acenv="source ./env/bin/activate"

# --- yt-dlp Helper Functions for Zsh Shell ---

# Base directory and cookie file path (adjust if needed)
_YT_VIDEO_DIR="$HOME/Videos"
_YT_COOKIES_FILE="$_YT_VIDEO_DIR/www.youtube.com_cookies.txt"

# --- Standard Video Downloads ---

yt_1080() {
    if [[ $# -ne 1 ]]; then
        echo "Usage: yt_1080 <url>" >&2 # Print errors to stderr
        return 1
    fi
    local url="$1"
    local output_format="$_YT_VIDEO_DIR/%(upload_date>%Y-%m-%d)s - %(title)s.%(ext)s"

    yt-dlp -f "bv[height<=1080][fps<=60]+ba" \
           --cookies "$_YT_COOKIES_FILE" \
           --embed-chapters --embed-metadata --embed-info-json --embed-thumbnail \
           --sponsorblock-remove all \
           -o "$output_format" \
           "$url"
}

yt_720() {
    if [[ $# -ne 1 ]]; then
        echo "Usage: yt_720 <url>" >&2
        return 1
    fi
    local url="$1"
    local output_format="$_YT_VIDEO_DIR/%(upload_date>%Y-%m-%d)s - %(title)s.%(ext)s"

    yt-dlp -f "bv[height<=720][fps<=60]+ba" \
           --cookies "$_YT_COOKIES_FILE" \
           --embed-chapters --embed-metadata --embed-info-json --embed-thumbnail \
           --sponsorblock-remove all \
           -o "$output_format" \
           "$url"
}

yt_480() {
    if [[ $# -ne 1 ]]; then
        echo "Usage: yt_480 <url>" >&2
        return 1
    fi
    local url="$1"
    local output_format="$_YT_VIDEO_DIR/%(upload_date>%Y-%m-%d)s - %(title)s.%(ext)s"

    yt-dlp -f "bv[height<=480][fps<=60]+ba" \
           --cookies "$_YT_COOKIES_FILE" \
           --embed-chapters --embed-metadata --embed-info-json --embed-thumbnail \
           --sponsorblock-remove all \
           -o "$output_format" \
           "$url"
}

yt() {
    if [[ $# -ne 2 ]]; then
        echo "Usage: yt <quality> <url>" >&2
        echo "Example: yt 720 'video_url'" >&2
        return 1
    fi
    local quality="$1"
    local url="$2"
    local output_format="$_YT_VIDEO_DIR/%(upload_date>%Y-%m-%d)s - %(title)s.%(ext)s"

    yt-dlp -f "bv[height<=$quality][fps<=60]+ba" \
           --cookies "$_YT_COOKIES_FILE" \
           --embed-chapters --embed-metadata --embed-info-json --embed-thumbnail \
           --sponsorblock-remove all \
           -o "$output_format" \
           "$url"
}

# --- Playlist Video Downloads ---

yt_1080_p() {
    if [[ $# -ne 1 ]]; then
        echo "Usage: yt_1080_p <playlist_url>" >&2
        return 1
    fi
    local url="$1"
    local output_format="$_YT_VIDEO_DIR/%(playlist)s/%(upload_date>%Y-%m-%d)s - %(title)s.%(ext)s"

    yt-dlp -f "bv[height<=1080][fps<=60]+ba" \
           --cookies "$_YT_COOKIES_FILE" \
           --embed-chapters --embed-metadata --embed-info-json --embed-thumbnail \
           --sponsorblock-remove all \
           -o "$output_format" \
           "$url"
}

yt_720_p() {
    if [[ $# -ne 1 ]]; then
        echo "Usage: yt_720_p <playlist_url>" >&2
        return 1
    fi
    local url="$1"
    local output_format="$_YT_VIDEO_DIR/%(playlist)s/%(upload_date>%Y-%m-%d)s - %(title)s.%(ext)s"

    yt-dlp -f "bv[height<=720][fps<=60]+ba" \
           --cookies "$_YT_COOKIES_FILE" \
           --embed-chapters --embed-metadata --embed-info-json --embed-thumbnail \
           --sponsorblock-remove all \
           -o "$output_format" \
           "$url"
}

yt_480_p() {
    if [[ $# -ne 1 ]]; then
        echo "Usage: yt_480_p <playlist_url>" >&2
        return 1
    fi
    local url="$1"
    local output_format="$_YT_VIDEO_DIR/%(playlist)s/%(upload_date>%Y-%m-%d)s - %(title)s.%(ext)s"

    yt-dlp -f "bv[height<=480][fps<=60]+ba" \
           --cookies "$_YT_COOKIES_FILE" \
           --embed-chapters --embed-metadata --embed-info-json --embed-thumbnail \
           --sponsorblock-remove all \
           -o "$output_format" \
           "$url"
}

yt_p() {
    if [[ $# -ne 2 ]]; then
        echo "Usage: yt_p <quality> <playlist_url>" >&2
        echo "Example: yt_p 720 'playlist_url'" >&2
        return 1
    fi
    local quality="$1"
    local url="$2"
    local output_format="$_YT_VIDEO_DIR/%(playlist)s/%(upload_date>%Y-%m-%d)s - %(title)s.%(ext)s"

    yt-dlp -f "bv[height<=$quality][fps<=60]+ba" \
           --cookies "$_YT_COOKIES_FILE" \
           --embed-chapters --embed-metadata --embed-info-json --embed-thumbnail \
           --sponsorblock-remove all \
           -o "$output_format" \
           "$url"
}

# --- Audio Only Downloads ---

yt_a() {
    if [[ $# -ne 1 ]]; then
        echo "Usage: yt_a <url>" >&2
        return 1
    fi
    local url="$1"
    local output_format="$_YT_VIDEO_DIR/%(title)s.%(ext)s" # Note: No date prefix in original PS script

    yt-dlp -f "ba" --extract-audio --audio-quality 0 \
           --cookies "$_YT_COOKIES_FILE" \
           --embed-chapters --embed-metadata --embed-info-json --embed-thumbnail \
           --sponsorblock-remove all \
           -o "$output_format" \
           "$url"
}

yt_a_p() {
    if [[ $# -ne 1 ]]; then
        echo "Usage: yt_a_p <playlist_url>" >&2
        return 1
    fi
    local url="$1"
    local output_format="$_YT_VIDEO_DIR/%(playlist)s/%(playlist_index)s - %(title)s.%(ext)s"

    yt-dlp -f "ba" --extract-audio --audio-quality 0 \
           --cookies "$_YT_COOKIES_FILE" \
           --embed-chapters --embed-metadata --embed-info-json --embed-thumbnail \
           --sponsorblock-remove all \
           -o "$output_format" \
           "$url"
}

# Optional: Unset global-like variables if desired (though underscore prefix usually indicates internal use)
# unset _YT_VIDEO_DIR _YT_COOKIES_FILE

# Dracula Theme (for zsh-syntax-highlighting)
#
# https://github.com/zenorocha/dracula-theme
#
# Copyright 2021, All rights reserved
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main cursor)
typeset -gA ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[comment]='fg=#6272A4'
ZSH_HIGHLIGHT_STYLES[alias]='fg=#50FA7B'
ZSH_HIGHLIGHT_STYLES[suffix-alias]='fg=#50FA7B'
ZSH_HIGHLIGHT_STYLES[global-alias]='fg=#50FA7B'
ZSH_HIGHLIGHT_STYLES[function]='fg=#50FA7B'
ZSH_HIGHLIGHT_STYLES[command]='fg=#50FA7B'
ZSH_HIGHLIGHT_STYLES[precommand]='fg=#50FA7B,italic'
ZSH_HIGHLIGHT_STYLES[autodirectory]='fg=#FFB86C,italic'
ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=#FFB86C'
ZSH_HIGHLIGHT_STYLES[double-hyphen-option]='fg=#FFB86C'
ZSH_HIGHLIGHT_STYLES[back-quoted-argument]='fg=#BD93F9'
ZSH_HIGHLIGHT_STYLES[builtin]='fg=#8BE9FD'
ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=#8BE9FD'
ZSH_HIGHLIGHT_STYLES[hashed-command]='fg=#8BE9FD'
ZSH_HIGHLIGHT_STYLES[commandseparator]='fg=#FF79C6'
ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter]='fg=#F8F8F2'
ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter-unquoted]='fg=#F8F8F2'
ZSH_HIGHLIGHT_STYLES[process-substitution-delimiter]='fg=#F8F8F2'
ZSH_HIGHLIGHT_STYLES[back-quoted-argument-delimiter]='fg=#FF79C6'
ZSH_HIGHLIGHT_STYLES[back-double-quoted-argument]='fg=#FF79C6'
ZSH_HIGHLIGHT_STYLES[back-dollar-quoted-argument]='fg=#FF79C6'
ZSH_HIGHLIGHT_STYLES[command-substitution-quoted]='fg=#F1FA8C'
ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter-quoted]='fg=#F1FA8C'
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=#F1FA8C'
ZSH_HIGHLIGHT_STYLES[single-quoted-argument-unclosed]='fg=#FF5555'
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=#F1FA8C'
ZSH_HIGHLIGHT_STYLES[double-quoted-argument-unclosed]='fg=#FF5555'
ZSH_HIGHLIGHT_STYLES[rc-quote]='fg=#F1FA8C'
## Variables
ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]='fg=#F8F8F2'
ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument-unclosed]='fg=#FF5555'
ZSH_HIGHLIGHT_STYLES[dollar-double-quoted-argument]='fg=#F8F8F2'
ZSH_HIGHLIGHT_STYLES[assign]='fg=#F8F8F2'
ZSH_HIGHLIGHT_STYLES[named-fd]='fg=#F8F8F2'
ZSH_HIGHLIGHT_STYLES[numeric-fd]='fg=#F8F8F2'
## No category relevant in spec
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=#FF5555'
ZSH_HIGHLIGHT_STYLES[path]='fg=#F8F8F2'
ZSH_HIGHLIGHT_STYLES[path_pathseparator]='fg=#FF79C6'
ZSH_HIGHLIGHT_STYLES[path_prefix]='fg=#F8F8F2'
ZSH_HIGHLIGHT_STYLES[path_prefix_pathseparator]='fg=#FF79C6'
ZSH_HIGHLIGHT_STYLES[globbing]='fg=#F8F8F2'
ZSH_HIGHLIGHT_STYLES[history-expansion]='fg=#BD93F9'
ZSH_HIGHLIGHT_STYLES[back-quoted-argument-unclosed]='fg=#FF5555'
ZSH_HIGHLIGHT_STYLES[redirection]='fg=#F8F8F2'
ZSH_HIGHLIGHT_STYLES[arg0]='fg=#F8F8F2'
ZSH_HIGHLIGHT_STYLES[default]='fg=#F8F8F2'
ZSH_HIGHLIGHT_STYLES[cursor]='standout'

source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme
