# yt-dlp shortcuts (ported from PowerShell profile)
VIDEO_ROOT="$HOME/Videos"
YT_COOKIES="$VIDEO_ROOT/www.youtube.com_cookies.txt"
CS_COOKIES="$VIDEO_ROOT/curiositystream.com_cookies.txt"

COMMON_META=(--embed-chapters --embed-metadata --embed-info-json --embed-thumbnail)
# English subtitles only (manual first, auto-generated as fallback), embedded in the video
ENG_SUBS=(--write-subs --write-auto-subs --sub-langs 'en.*,-en-orig,-live_chat' --embed-subs)
# Smallest file at the same quality: prefer AV1 > VP9 > H.264 and Opus audio, no re-encoding, MKV container
EFFICIENT=(-S 'vcodec:av01,acodec:opus,size' --merge-output-format mkv)
YT_ARGS=(--cookies "$YT_COOKIES" "${COMMON_META[@]}" --sponsorblock-remove all)

# ---- CuriosityStream ----
_cs_dl() {
    yt-dlp -f "bv[height<=$1]+ba" "${EFFICIENT[@]}" --cookies "$CS_COOKIES" "${COMMON_META[@]}" "${ENG_SUBS[@]}" \
        -o "$VIDEO_ROOT/Curiosity_Stream/%(playlist)s/%(title)s.%(ext)s" "$2"
}
cs_2160() { _cs_dl 2160 "$1"; }
cs_1440() { _cs_dl 1440 "$1"; }
cs_1080() { _cs_dl 1080 "$1"; }
cs_720()  { _cs_dl 720  "$1"; }

# ---- YouTube video ----
# usage: _yt_video <quality> <url> [playlist|single] [short]
_yt_video() {
    local out="$VIDEO_ROOT/%(upload_date>%Y-%m-%d)s - %(title)s.%(ext)s"
    [[ "$3" == playlist ]] && out="$VIDEO_ROOT/%(playlist)s/%(upload_date>%Y-%m-%d)s - %(title)s.%(ext)s"
    local extra=()
    [[ "$4" == short ]] && extra=(--match-filter 'duration < 60')
    yt-dlp -f "bv[height<=$1][fps<=60]+ba" "${EFFICIENT[@]}" "${extra[@]}" "${YT_ARGS[@]}" "${ENG_SUBS[@]}" -o "$out" "$2"
}
yt_480_d()  { _yt_video 480 "$1" single short; }
yt_1080()   { _yt_video 1080 "$1"; }
yt_720()    { _yt_video 720  "$1"; }
yt_480()    { _yt_video 480  "$1"; }
yt()        { _yt_video "$1" "$2"; }
yt_1080_p() { _yt_video 1080 "$1" playlist; }
yt_720_p()  { _yt_video 720  "$1" playlist; }
yt_480_p()  { _yt_video 480  "$1" playlist; }
yt_p()      { _yt_video "$1" "$2" playlist; }

# ---- YouTube audio ----
_yt_audio() {
    local out="$VIDEO_ROOT/%(title)s.%(ext)s"
    [[ "$2" == playlist ]] && out="$VIDEO_ROOT/%(playlist)s/%(playlist_index)s - %(title)s.%(ext)s"
    yt-dlp -f ba --extract-audio --audio-quality 0 "${YT_ARGS[@]}" -o "$out" "$1"
}
yt_a()   { _yt_audio "$1"; }
yt_a_p() { _yt_audio "$1" playlist; }
