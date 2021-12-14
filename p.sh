sudo pacman -Syyuu
sudo pacman -S yay base-devel

sudo pacman -S --needed $(comm -12 <(pacman -Slq|sort) <(sort pkglist.txt) )
yay -S --noedit --noconfirm --needed localpkglist.txt