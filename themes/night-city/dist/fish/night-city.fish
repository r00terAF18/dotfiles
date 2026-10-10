# Night City (Cyberpunk 2077) colours for fish, plus the starship prompt switch.
# Generated from themes/night-city/palette.sh by generate.sh; edit the template, not dist/.
# Linked to ~/.config/fish/conf.d/night-city.fish by install.sh. Everything is set in
# global scope, so removing this file restores your own (universal) fish colours.

status is-interactive; or return

# Use the Night City starship prompt (also set for the whole session via environment.d).
if test -r $HOME/.config/night-city/starship/starship.toml
    set -gx STARSHIP_CONFIG $HOME/.config/night-city/starship/starship.toml
end

# Syntax highlighting
set -g fish_color_normal E4F7F7
set -g fish_color_command 00F0FF
set -g fish_color_keyword FF2BD6
set -g fish_color_quote FCEE0A
set -g fish_color_redirection FF8A00
set -g fish_color_end FF8A00
set -g fish_color_error FF003C
set -g fish_color_param E4F7F7
set -g fish_color_option 02D7F2
set -g fish_color_comment 7A8C99
set -g fish_color_operator 00FF9F
set -g fish_color_escape FF2BD6
set -g fish_color_autosuggestion 555B70
set -g fish_color_valid_path --underline
set -g fish_color_selection --background=1B1D26
set -g fish_color_search_match --background=2A2D3A
set -g fish_color_history_current --bold
set -g fish_color_cancel FF003C --reverse
set -g fish_color_cwd FCEE0A
set -g fish_color_cwd_root FF003C
set -g fish_color_user 00F0FF
set -g fish_color_host E4F7F7
set -g fish_color_host_remote FF8A00
set -g fish_color_status FF003C

# Completion pager
set -g fish_pager_color_progress 0A0A0F --background=FCEE0A
set -g fish_pager_color_prefix FCEE0A --bold
set -g fish_pager_color_completion E4F7F7
set -g fish_pager_color_description 7A8C99
set -g fish_pager_color_selected_background --background=1B1D26
