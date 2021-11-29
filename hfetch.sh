#!/bin/sh

tmpfile="$(mktemp)"

# echo "$2" | grep -qE '^[0-9]+$' && height="$2" || height="$(($(stty size | awk '{print $1}') - 5))"
# [ "$DEBUG" = "true" ] && echo "Using height $height"

if [ $(echo "$1" | grep "#*[[:digit:]]*") ]; then
	
	id=$(echo "$1" | grep -o "[[:digit:]]*")
else
	nurl=$(curl -fsSL "https://wholesomelist.com/random" | grep -m1 -o "https://nhentai\.net/g/[[:digit:]]*")
	id=$(echo "$nurl" | grep -o "[[:digit:]]*")
fi


url=$(curl -fsSL "https://nhentai.net/g/$id/" | grep -o "https://t\.nhentai\.net/galleries/[[:digit:]]*/cover\.[[:lower:]]*" | head -1)

format=$(echo "$url" | grep -o "\.[[:lower:]]*$")

# echo "$id"
# echo "$url"
# echo "$tmpfile" 
# echo "$format"

curl -fsSLo "$tmpfile$format" "$url"

if [ "$format" = ".gif" ]; then
	convert "$tmpfile$format[0]" "$tmpfile.jpg"
	rm "$tmpfile$format"
	mv "$tmpfile.jpg" "$tmpfile$format"
fi
	


if [ "$TERM" = "xterm-kitty" ]; then
    command -v convert > /dev/null 2>&1 && neofetch --kitty "$tmpfile$format" || kitty_imagemagick_warn=true
    if [ "$kitty_imagemagick_warn" = "true" ]; then
        neofetch --jp2a "$tmpfile$format"
    fi
else
    neofetch --jp2a "$tmpfile$format"
fi
printf "mNHentai tag: #$id\n"

rm "$tmpfile" "$tmpfile$format"

[ "$kitty_imagemagick_warn" = "true" ] && echo "WARN: imagemagick is required for kitty image backend"
