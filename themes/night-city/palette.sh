# shellcheck shell=bash
# Night City palette: the single source of truth for every colour in this theme.
# Edit a value here, then run ./generate.sh (install.sh does that for you).
#
# Templates use {{name}} -> "#RRGGBB", {{name_hex}} -> "RRGGBB", {{name_rgb}} -> "R, G, B",
# where name is the variable below without the NC_ prefix, lowercased (NC_YELLOW_DIM -> yellow_dim).

# Surfaces
NC_BG0="#0A0A0F"         # void black: windows, terminal background
NC_BG1="#12131A"         # surfaces: views, sidebars, popovers
NC_BG2="#1B1D26"         # cards, inactive tabs, ANSI black
NC_BORDER="#2A2D3A"      # borders, separators

# Text
NC_FG="#E4F7F7"          # main text
NC_FG_DIM="#7A8C99"      # secondary text, comments

# Neon accents
NC_YELLOW="#FCEE0A"      # main accent (Cyberpunk 2077 yellow); always put bg0 text on it
NC_YELLOW_DIM="#C4B800"
NC_CYAN="#00F0FF"
NC_CYAN_DIM="#02D7F2"
NC_RED="#FF003C"
NC_MAGENTA="#FF2BD6"
NC_GREEN="#00FF9F"       # netrunner green
NC_ORANGE="#FF8A00"
NC_BLUE="#3D7BFF"
NC_PURPLE="#B967FF"

# Terminal bright variants (ANSI 8-15)
NC_BRIGHT_BLACK="#555B70"
NC_BRIGHT_RED="#FF4D6D"
NC_BRIGHT_GREEN="#5CFFC0"
NC_BRIGHT_YELLOW="#FFF75C"
NC_BRIGHT_BLUE="#7AA5FF"
NC_BRIGHT_MAGENTA="#FF7AE6"
NC_BRIGHT_CYAN="#66F6FF"
NC_BRIGHT_WHITE="#FFFFFF"
