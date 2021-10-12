pacman -Syyuu
pacmna -S yay

pacman -S --needed $(comm -12 <(pacman -Slq|sort) <(sort pkglist.txt) )
yay -S --noedit --noconfirm --needed localpkglist.txt