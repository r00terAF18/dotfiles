# One-time system setup (needs sudo, not automated)

Things set up by hand on this laptop that live outside `$HOME`:

```sh
# Bluetooth (EndeavourOS ships it disabled)
sudo systemctl enable --now bluetooth

# Intel thermal daemon (less throttling on the i5-1135G7)
sudo systemctl enable --now thermald

# GNOME Software without Flatpak: PackageKit + Arch app catalog
sudo pacman -S --needed archlinux-appstream-data fwupd

# PipeWire JACK for 32-bit games (avoids the jack2 conflict)
sudo pacman -S --needed lib32-pipewire-jack
```

Gaming extras (Steam/Proton): after `packages/install.sh`, open ProtonUp-Qt
and install the latest GE-Proton as a fallback next to Proton Experimental.

Not stored in this repo on purpose: yt-dlp cookie files (`~/Videos/*cookies*.txt`),
tiddl login (`~/.tiddl/auth.json`), SSH/GPG keys. Copy those over manually.
