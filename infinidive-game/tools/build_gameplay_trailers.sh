#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MEDIA_DIR="${PROJECT_ROOT}/assets/store/gameplay"
SOURCE_VIDEO="${MEDIA_DIR}/trailer-runtime-dev-17s.mp4"
SOCIAL_VIDEO="${MEDIA_DIR}/trailer-runtime-social-17s.mp4"
APPLE_CANDIDATE="${MEDIA_DIR}/trailer-runtime-apple-candidate-886x1920-17s.mp4"
APPLE_POSTER="${MEDIA_DIR}/trailer-runtime-apple-poster-5s-886x1920.jpg"
GODOT_BIN="${INFINIDIVE_GODOT_BIN:-${PROJECT_ROOT}/../../.runtime/Godot_v4.7.2-stable_linux.x86_64}"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/infinidive-trailer.XXXXXX")"
AUDIO_WAV="${TEMP_DIR}/procedural-audio.wav"
TEMP_SOCIAL="${TEMP_DIR}/trailer-runtime-social-17s.mp4"
TEMP_APPLE_CANDIDATE="${TEMP_DIR}/trailer-runtime-apple-candidate-886x1920-17s.mp4"
TEMP_APPLE_POSTER="${TEMP_DIR}/trailer-runtime-apple-poster-5s-886x1920.jpg"

cleanup() {
	rm -rf "${TEMP_DIR}"
}
trap cleanup EXIT

for command_name in ffmpeg ffprobe jq sha256sum; do
	command -v "${command_name}" >/dev/null
done
test -x "${GODOT_BIN}"
test -f "${SOURCE_VIDEO}"

"${GODOT_BIN}" --headless --path "${PROJECT_ROOT}" \
	--scene res://tools/trailer_audio_renderer.tscn -- "${AUDIO_WAV}"

# Full 1080x1920 runtime pixels are preserved byte-for-byte; only the shipped
# procedural audio track is muxed in. This is the primary Android/social asset.
ffmpeg -hide_banner -loglevel error -y \
	-i "${SOURCE_VIDEO}" -i "${AUDIO_WAV}" \
	-map 0:v:0 -map 1:a:0 -c:v copy \
	-c:a aac -b:a 256k -ar 48000 -ac 2 -shortest \
	-movflags +faststart -metadata title="INFINIDIVE runtime gameplay" \
	"${TEMP_SOCIAL}"

# Apple currently accepts exactly 886x1920 for portrait iPhone previews. The
# source is 9:16, so it is proportionally reduced to 886x1576 and vertically
# letterboxed to 886x1920. No gameplay is cropped; 172px black padding is added
# above and below the scaled runtime frame.
ffmpeg -hide_banner -loglevel error -y \
	-i "${SOURCE_VIDEO}" -i "${AUDIO_WAV}" \
	-filter_complex "[0:v]scale=886:-2:flags=lanczos,pad=886:1920:0:(oh-ih)/2:color=black,fps=30,format=yuv420p[v]" \
	-map "[v]" -map 1:a:0 -t 17.2 \
	-c:v libx264 -preset slow -profile:v high -level:v 4.0 \
	-b:v 10M -minrate 10M -maxrate 10M -bufsize 20M \
	-x264-params "nal-hrd=cbr:force-cfr=1" \
	-c:a aac -b:a 256k -ar 48000 -ac 2 \
	-movflags +faststart -metadata title="INFINIDIVE App Preview format candidate" \
	"${TEMP_APPLE_CANDIDATE}"

ffmpeg -hide_banner -loglevel error -y -ss 5 \
	-i "${TEMP_APPLE_CANDIDATE}" -frames:v 1 -q:v 2 "${TEMP_APPLE_POSTER}"

social_probe="$(ffprobe -v error -show_entries stream=codec_type,codec_name,profile,width,height,pix_fmt,level,field_order,r_frame_rate,sample_rate,channels,channel_layout,bit_rate:format=duration,size -of json "${TEMP_SOCIAL}")"
apple_probe="$(ffprobe -v error -show_entries stream=codec_type,codec_name,profile,width,height,pix_fmt,level,field_order,r_frame_rate,sample_rate,channels,channel_layout,bit_rate:format=duration,size -of json "${TEMP_APPLE_CANDIDATE}")"

jq -e '
	(.format.duration | tonumber) >= 15 and (.format.duration | tonumber) <= 30 and
	([.streams[] | select(.codec_type == "video")][0] |
		.codec_name == "h264" and .profile == "High" and .width == 1080 and .height == 1920 and
		.pix_fmt == "yuv420p" and .level <= 40 and .field_order == "progressive" and .r_frame_rate == "30/1") and
	([.streams[] | select(.codec_type == "audio")][0] |
		.codec_name == "aac" and .sample_rate == "48000" and .channels == 2 and .channel_layout == "stereo")
' >/dev/null <<<"${social_probe}"

jq -e '
	(.format.duration | tonumber) >= 15 and (.format.duration | tonumber) <= 30 and
	(.format.size | tonumber) < 500000000 and
	([.streams[] | select(.codec_type == "video")][0] |
		.codec_name == "h264" and .profile == "High" and .width == 886 and .height == 1920 and
		.pix_fmt == "yuv420p" and .level <= 40 and .field_order == "progressive" and .r_frame_rate == "30/1" and
		(.bit_rate | tonumber) >= 10000000 and (.bit_rate | tonumber) <= 12000000) and
	([.streams[] | select(.codec_type == "audio")][0] |
		.codec_name == "aac" and .sample_rate == "48000" and .channels == 2 and .channel_layout == "stereo" and
		(.bit_rate | tonumber) >= 240000 and (.bit_rate | tonumber) <= 280000)
' >/dev/null <<<"${apple_probe}"

ffmpeg -hide_banner -v error -i "${TEMP_SOCIAL}" -f null -
ffmpeg -hide_banner -v error -i "${TEMP_APPLE_CANDIDATE}" -f null -

# Publish only after every contract and decode check passes. Renames stay on the
# same filesystem, so readers never observe a partially written MP4/JPEG.
mv "${TEMP_SOCIAL}" "${SOCIAL_VIDEO}"
mv "${TEMP_APPLE_CANDIDATE}" "${APPLE_CANDIDATE}"
mv "${TEMP_APPLE_POSTER}" "${APPLE_POSTER}"

sha256sum "${AUDIO_WAV}" "${SOURCE_VIDEO}" "${SOCIAL_VIDEO}" "${APPLE_CANDIDATE}" "${APPLE_POSTER}"
printf '%s\n' "TRAILER_BUILD_OK"
