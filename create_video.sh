#!/bin/bash

# Script to create MP4 video from segmented audio and images
# This script creates individual segments and then concatenates them
#
# Usage: ./create_video.sh [content_directory]
#   If content_directory is not provided, uses current directory

set -e  # Exit on any error

# Get content directory from argument or use current directory
if [ -n "$1" ]; then
    CONTENT_DIR="$(cd "$1" && pwd)"
else
    CONTENT_DIR="$(pwd)"
fi

# Validate content directory exists
if [ ! -d "$CONTENT_DIR" ]; then
    echo "❌ Error: Content directory does not exist: $CONTENT_DIR"
    exit 1
fi

SEGMENTS_DIR="$CONTENT_DIR/segments"
OUTPUT_DIR="$CONTENT_DIR/output"

# Create directories for segments and output
mkdir -p "$SEGMENTS_DIR"
mkdir -p "$OUTPUT_DIR"

echo "🎬 Starting video creation process..."
echo "📁 Content directory: $CONTENT_DIR"
echo ""

# Auto-detect number of segments by finding audio files
AUDIO_FILES=("$CONTENT_DIR"/audio_*.wav)
if [ ! -e "${AUDIO_FILES[0]}" ]; then
    echo "❌ Error: No audio files found (audio_*.wav) in $CONTENT_DIR"
    exit 1
fi

# Extract segment numbers and find max
MAX_SEGMENT=0
for audio_file in "${AUDIO_FILES[@]}"; do
    # Extract number from filename (e.g., audio_10.wav -> 10)
    SEGMENT_NUM=$(basename "$audio_file" | sed 's/audio_\([0-9]*\)\.wav/\1/')
    if [ "$SEGMENT_NUM" -gt "$MAX_SEGMENT" ]; then
        MAX_SEGMENT=$SEGMENT_NUM
    fi
done

echo "📊 Found $MAX_SEGMENT segment(s)"
echo ""

# Step 1: Generate individual video segments
echo "Step 1: Creating individual video segments..."
SEGMENTS_CREATED=0

for i in $(seq 1 "$MAX_SEGMENT"); do
    IMAGE_FILE="$CONTENT_DIR/image_$i.png"
    AUDIO_FILE="$CONTENT_DIR/audio_$i.wav"
    SEGMENT_FILE="$SEGMENTS_DIR/segment_$i.mp4"
    
    # Check if files exist
    if [ ! -f "$IMAGE_FILE" ]; then
        echo "⚠️  Warning: $IMAGE_FILE not found, skipping segment $i"
        continue
    fi
    if [ ! -f "$AUDIO_FILE" ]; then
        echo "⚠️  Warning: $AUDIO_FILE not found, skipping segment $i"
        continue
    fi
    
    echo "  Creating segment $i/$MAX_SEGMENT..."
    
    # Create video segment: loop image for duration of audio
    if ffmpeg -loop 1 -i "$IMAGE_FILE" -i "$AUDIO_FILE" \
        -c:v libx264 -tune stillimage -pix_fmt yuv420p \
        -c:a aac -b:a 192k \
        -shortest -y \
        "$SEGMENT_FILE" 2>/dev/null; then
        echo "  ✅ Segment $i created successfully"
        SEGMENTS_CREATED=$((SEGMENTS_CREATED + 1))
    else
        echo "  ❌ Error creating segment $i"
        exit 1
    fi
done

if [ $SEGMENTS_CREATED -eq 0 ]; then
    echo "❌ No segments were created. Please check your input files."
    exit 1
fi

echo ""
echo "Step 2: Creating concatenation list..."

# Step 2: Create concatenation list file
CONCAT_LIST="$SEGMENTS_DIR/concat_list.txt"
> "$CONCAT_LIST"  # Clear/create the file

for i in $(seq 1 "$MAX_SEGMENT"); do
    SEGMENT_FILE="$SEGMENTS_DIR/segment_$i.mp4"
    if [ -f "$SEGMENT_FILE" ]; then
        # Use absolute path for concat file to avoid path issues
        echo "file '$SEGMENT_FILE'" >> "$CONCAT_LIST"
    fi
done

echo "  ✅ Concatenation list created with $(wc -l < "$CONCAT_LIST") segments"
echo ""

# Step 3: Concatenate all segments
echo "Step 3: Concatenating all segments into final video..."
FINAL_OUTPUT="$OUTPUT_DIR/final_video.mp4"

if ffmpeg -f concat -safe 0 -i "$CONCAT_LIST" \
    -c copy -y \
    "$FINAL_OUTPUT" 2>/dev/null; then
    echo ""
    echo "✅ SUCCESS! Final video created: $FINAL_OUTPUT"
    echo ""
    # Get file size
    if command -v stat >/dev/null 2>&1; then
        SIZE=$(stat -f%z "$FINAL_OUTPUT" 2>/dev/null || stat -c%s "$FINAL_OUTPUT" 2>/dev/null)
        if command -v bc >/dev/null 2>&1; then
            SIZE_MB=$(echo "scale=2; $SIZE / 1024 / 1024" | bc)
            echo "📊 File size: ${SIZE_MB} MB"
        else
            SIZE_MB=$((SIZE / 1024 / 1024))
            echo "📊 File size: ~${SIZE_MB} MB"
        fi
    fi
else
    echo ""
    echo "❌ Error during concatenation"
    exit 1
fi

echo ""
echo "🎉 Process complete!"

