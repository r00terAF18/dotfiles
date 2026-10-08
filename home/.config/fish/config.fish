# ~/.config/fish/config.fish  (managed by ~/dotfiles)

# uv / user tools
fish_add_path "$HOME/.local/bin"

if status is-interactive
    # No greeting
    set fish_greeting

    # Prompt
    if type -q starship
        starship init fish | source
    end

    # Aliases
    alias pamcan pacman
    alias clear "printf '\033[2J\033[3J\033[1;1H'"
    if type -q eza
        alias ls 'eza --icons'
    end
end

# yt-dlp shortcuts live in conf.d/yt-dlp.fish, nvm.fish in conf.d/nvm.fish (fisher)
