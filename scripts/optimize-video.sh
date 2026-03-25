#!/usr/bin/env bash
# optimize-video.sh — Convert any video to the optimal format for VideoWallpaper
#
# Output: H.265 (HEVC) / 1080p / 30fps / SDR / AAC-muted / .mp4
# Requires: ffmpeg (brew install ffmpeg)
#
# Usage:
#   ./scripts/optimize-video.sh <input> [output]
#
# Examples:
#   ./scripts/optimize-video.sh ~/Downloads/scenery.mov
#   ./scripts/optimize-video.sh ~/Downloads/scenery.mov ~/Desktop/wallpaper.mp4

set -euo pipefail

# ── helpers ──────────────────────────────────────────────────────────────────

usage() {
    echo "Usage: $0 <input_video> [output_video]"
    echo ""
    echo "Converts a video to the optimal format for VideoWallpaper:"
    echo "  • Codec  : H.265 (HEVC) — hardware-accelerated on Apple Silicon / Intel Mac"
    echo "  • Size   : 1920×1080 (downscale only; portrait/square videos are letterboxed)"
    echo "  • FPS    : 30 (capped; source with lower fps is kept as-is)"
    echo "  • Color  : SDR (BT.709) — HDR is tone-mapped to prevent washed-out colors"
    echo "  • Audio  : silent (muted by default in-app)"
    echo "  • Format : MP4"
    exit 1
}

check_ffmpeg() {
    if ! command -v ffmpeg &>/dev/null; then
        echo "Error: ffmpeg not found. Install it with:"
        echo "  brew install ffmpeg"
        exit 1
    fi
}

# ── argument handling ─────────────────────────────────────────────────────────

[[ $# -lt 1 ]] && usage

INPUT="$1"

if [[ ! -f "$INPUT" ]]; then
    echo "Error: input file not found: $INPUT"
    exit 1
fi

if [[ $# -ge 2 ]]; then
    OUTPUT="$2"
else
    BASENAME="$(basename "$INPUT")"
    STEM="${BASENAME%.*}"
    OUTPUT="${STEM}_wallpaper.mp4"
fi

# ── main ──────────────────────────────────────────────────────────────────────

check_ffmpeg

echo "Input : $INPUT"
echo "Output: $OUTPUT"
echo ""

# Probe whether the source is HDR (bt2020/smpte2084/arib-std-b67 transfer)
HDR=$(ffprobe -v quiet -select_streams v:0 \
    -show_entries stream=color_transfer,color_space,color_primaries \
    -of default=noprint_wrappers=1 "$INPUT" 2>/dev/null || true)

TONEMAP_FILTERS=""
if echo "$HDR" | grep -qiE "smpte2084|arib.std.b67|bt2020"; then
    echo "Detected HDR — will tone-map to SDR (BT.709)"
    # zscale tone-mapping: bt2020 PQ → bt709
    TONEMAP_FILTERS=",zscale=transfer=linear:npl=100,format=gbrpf32le,zscale=primaries=bt709,tonemap=tonemap=hable:desat=0,zscale=transfer=bt709:matrix=bt709:range=limited,format=yuv420p"
fi

# Scale filter:
#   - Downscale to fit within 1920×1080 (never upscale)
#   - Pad to exactly 1920×1080 with black bars (handles portrait / non-16:9)
#   - Use lanczos for quality
SCALE_FILTER="scale=w=1920:h=1080:force_original_aspect_ratio=decrease:flags=lanczos,pad=1920:1080:(ow-iw)/2:(oh-ih)/2"

# FPS filter: cap at 30, preserve lower fps sources
FPS_FILTER="fps=fps=min(30\\,source_fps)"

ffmpeg -i "$INPUT" \
    -vf "${SCALE_FILTER}${TONEMAP_FILTERS},${FPS_FILTER}" \
    -c:v libx265 \
    -preset slow \
    -crf 22 \
    -tag:v hvc1 \
    -color_range tv \
    -colorspace bt709 \
    -color_trc bt709 \
    -color_primaries bt709 \
    -movflags +faststart \
    -an \
    -y \
    "$OUTPUT"

echo ""
echo "Done: $OUTPUT"
echo ""

# Report file size
INPUT_SIZE=$(du -sh "$INPUT" | cut -f1)
OUTPUT_SIZE=$(du -sh "$OUTPUT" | cut -f1)
echo "  Before : $INPUT_SIZE  ($INPUT)"
echo "  After  : $OUTPUT_SIZE  ($OUTPUT)"
