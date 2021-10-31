
alias pmc="python manage.py createsuperuser"
alias pmk="python manage.py makemigrations"
alias pmm="python manage.py migrate"
alias pmr="python manage.py runserver"
alias acenv="source ./env/bin/activate"
alias nfetch="neofetch | lolcat"
getWeb() {
  wget --mirror --convert-links --adjust-extension --page-requisites --no-parent --no-check-certificate "$1"
}

ydl-v-720() {
	youtube-dl --ignore-config --yes-playlist --cookies ~/youtube.com_cookies.txt --embed-thumbnail -o "$1/%(playlist)s/%(playlist_index)s - %(title)s.%(ext)s" -f "bestvideo[height=720][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height=720]+bestaudio" "$2"
}

ydl-v-1080() {
	youtube-dl --ignore-config --yes-playlist --cookies ~/youtube.com_cookies.txt --embed-thumbnail -o "$1/%(playlist)s/%(playlist_index)s - %(title)s.%(ext)s" -f "bestvideo[height=1080][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height=1080]+bestaudio" "$2"
}

ydl-m() {
	youtube-dl -x --audio-format m4a --embed-thumbnail --cookies ~/youtube.com_cookies.txt -o "$1/%(title)s.%(ext)s" "$2"
}

ydl-m-p() {
	youtube-dl --ignore-config --yes-playlist -x --audio-format m4a --embed-thumbnail --cookies ~/youtube.com_cookies.txt -o "$1/%(playlist)s/%(playlist_index)s - %(title)s.%(ext)s" "$2"
}

cs-get() {
	youtube-dl --cookies "curiositystream.com_cookies.txt" --username "ahroohi1379+1@hotmail.com" --password "@LicenseMarket" -o '%(title)s.%(ext)' "$1"
}

split-vid() {
	python split.py -f "$1" -c 4
}
