#!/bin/bash


# create SSH
ssh-keygen -t ed25519 -C "ahroohi1379@hotmail.com"
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

ssh-keygen -t ed25519-sk -C "ahroohi1379@hotmail.com"
cat ~/.ssh/id_ed25519.pub