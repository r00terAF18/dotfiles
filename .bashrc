alias pmc="python manage.py createsuperuser"
alias pmk="python manage.py makemigrations"
alias pmm="python manage.py migrate"
alias pmr="python manage.py runserver"
alias startdb="sudo systemctl start mariadb"
alias acenv="source ./env/bin/activate"
alias startwind="sudo systemctl start windscribe"
alias nfetch="neofetch | lolcat"
getWeb() {
    wget --mirror --convert-links --adjust-extension --page-requisites --no-parent --no-check-certificate "$1"
}
ydl-m() {
	youtube-dl -x --audio-format flac -o '%(title)s.%(ext)s' "$1"
}

cs-get() {
	youtube-dl --cookies "curiositystream.com_cookies.txt" --username "ahroohi1379+1@hotmail.com" --password "@LicenseMarket" -o '%(title)s.%(ext)' "$1"
}

split-vid() {
	python split.py -f "$1" -c 4
}