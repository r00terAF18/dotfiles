#!/bin/bash

# declare variables
CUR_DIR = "/home/amir/.dotfiles"
HOME_DIR = "/home/amir"

# creates symlinks pretty much everything
ln -s "$CUR_DIR/.zshrc" "$HOME_DIR/.zshrc"
ln -s "$CUR_DIR/.p10k.zsh" "$HOME_DIR/.p10k.zsh"
ln -s "$CUR_DIR/.bashrc" "$HOME_DIR/.bahsrc"
ln -s "$CUR_DIR/kitty.conf" "$HOME_DIR/.config/kitty/kitty.conf"
ln -s "$CUR_DIR/.gitconfig" "$HOME_DIR/.gitconfig"
ln -s "$CUR_DIR/classes.py" "$HOME_DIR/classes.py"
ln -s "$CUR_DIR/split.py" "$HOME_DIR/split.py"

# move xfce4 keyboard and display shortcuts
mv "$CUR_DIR/xfce4" "$HOME_DIR/.config/"
