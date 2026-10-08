# yt-dlp shortcuts (ported from PowerShell profile)
status is-interactive; or return

set -g __video_root $HOME/Videos
set -g __yt_cookies $__video_root/www.youtube.com_cookies.txt
set -g __cs_cookies $__video_root/curiositystream.com_cookies.txt

set -g __common_meta --embed-chapters --embed-metadata --embed-info-json --embed-thumbnail
# English subtitles only (manual first, auto-generated as fallback), embedded in the video
set -g __eng_subs --write-subs --write-auto-subs --sub-langs 'en.*,-en-orig,-live_chat' --embed-subs
# Smallest file at the same quality: prefer AV1 > VP9 > H.264 and Opus audio, no re-encoding, MKV container
set -g __efficient -S 'vcodec:av01,acodec:opus,size' --merge-output-format mkv
set -g __yt_args --cookies $__yt_cookies $__common_meta --sponsorblock-remove all

# ---- CuriosityStream ----
function _cs_dl --argument-names quality url
    yt-dlp -f "bv[height<=$quality]+ba" $__efficient --cookies $__cs_cookies $__common_meta $__eng_subs \
        -o "$__video_root/Curiosity_Stream/%(playlist)s/%(title)s.%(ext)s" $url
end
function cs_2160; _cs_dl 2160 $argv[1]; end
function cs_1440; _cs_dl 1440 $argv[1]; end
function cs_1080; _cs_dl 1080 $argv[1]; end
function cs_720;  _cs_dl 720  $argv[1]; end

# ---- YouTube video ----
# usage: _yt_video <quality> <url> [playlist] [short]
function _yt_video --argument-names quality url mode short
    set -l out "$__video_root/%(upload_date>%Y-%m-%d)s - %(title)s.%(ext)s"
    test "$mode" = playlist; and set out "$__video_root/%(playlist)s/%(upload_date>%Y-%m-%d)s - %(title)s.%(ext)s"
    set -l extra
    test "$short" = short; and set extra --match-filter 'duration < 60'
    yt-dlp -f "bv[height<=$quality][fps<=60]+ba" $__efficient $extra $__yt_args $__eng_subs -o $out $url
end
function yt_480_d; _yt_video 480 $argv[1] single short; end
function yt_1080;  _yt_video 1080 $argv[1]; end
function yt_720;   _yt_video 720  $argv[1]; end
function yt_480;   _yt_video 480  $argv[1]; end
function yt;       _yt_video $argv[1] $argv[2]; end
function yt_1080_p; _yt_video 1080 $argv[1] playlist; end
function yt_720_p;  _yt_video 720  $argv[1] playlist; end
function yt_480_p;  _yt_video 480  $argv[1] playlist; end
function yt_p;      _yt_video $argv[1] $argv[2] playlist; end

# ---- YouTube audio ----
function _yt_audio --argument-names url mode
    set -l out "$__video_root/%(title)s.%(ext)s"
    test "$mode" = playlist; and set out "$__video_root/%(playlist)s/%(playlist_index)s - %(title)s.%(ext)s"
    yt-dlp -f ba --extract-audio --audio-quality 0 $__yt_args -o $out $url
end
function yt_a;   _yt_audio $argv[1]; end
function yt_a_p; _yt_audio $argv[1] playlist; end
