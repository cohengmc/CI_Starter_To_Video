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

# Set output folders to Desktop
MANDARIN_CI_DIR="/Users/geoffreycohen/Desktop/Mandarin CI"
SPANISH_CI_DIR="/Users/geoffreycohen/Desktop/Spanish CI"

# Create output directories
mkdir -p "$MANDARIN_CI_DIR"
mkdir -p "$SPANISH_CI_DIR"

SEGMENTS_DIR="$CONTENT_DIR/segments"

# Create directory for segments
mkdir -p "$SEGMENTS_DIR"

# Generate timestamp for output filename
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "🎬 Starting video creation process..."
echo "📁 Content directory: $CONTENT_DIR"
echo ""

# Function to process audio files with a given suffix
process_language() {
    local AUDIO_SUFFIX="$1"
    local LANGUAGE_LABEL="$2"
    local OUTPUT_DIR="$3"
    
    # Auto-detect number of segments by finding audio files
    if [ -z "$AUDIO_SUFFIX" ]; then
        # Get all audio files and exclude _es files
        AUDIO_FILES=($(ls "$CONTENT_DIR"/audio_*.wav 2>/dev/null | grep -v "_es.wav$"))
    else
        AUDIO_FILES=($(ls "$CONTENT_DIR"/audio_*${AUDIO_SUFFIX}.wav 2>/dev/null))
    fi
    
    if [ ${#AUDIO_FILES[@]} -eq 0 ] || [ ! -e "${AUDIO_FILES[0]}" ]; then
        return 1
    fi
    
    # Extract segment numbers and find max
    MAX_SEGMENT=0
    for audio_file in "${AUDIO_FILES[@]}"; do
        # Extract number from filename (e.g., audio_10.wav -> 10, audio_10_es.wav -> 10)
        if [ -z "$AUDIO_SUFFIX" ]; then
            SEGMENT_NUM=$(basename "$audio_file" | sed 's/audio_\([0-9]*\)\.wav/\1/')
        else
            SEGMENT_NUM=$(basename "$audio_file" | sed "s/audio_\([0-9]*\)${AUDIO_SUFFIX}\.wav/\1/")
        fi
        if [ "$SEGMENT_NUM" -gt "$MAX_SEGMENT" ]; then
            MAX_SEGMENT=$SEGMENT_NUM
        fi
    done
    
    if [ $MAX_SEGMENT -eq 0 ]; then
        return 1
    fi
    
    echo "📊 Found $MAX_SEGMENT segment(s) for $LANGUAGE_LABEL"
    echo ""
    
    # Step 1: Generate individual video segments
    echo "Step 1: Creating individual video segments for $LANGUAGE_LABEL..."
    SEGMENTS_CREATED=0
    SEGMENT_PREFIX="segment"
    if [ -n "$AUDIO_SUFFIX" ]; then
        SEGMENT_PREFIX="segment${AUDIO_SUFFIX}"
    fi
    
    for i in $(seq 1 "$MAX_SEGMENT"); do
        IMAGE_FILE="$CONTENT_DIR/image_$i.png"
        if [ -z "$AUDIO_SUFFIX" ]; then
            AUDIO_FILE="$CONTENT_DIR/audio_$i.wav"
            SEGMENT_FILE="$SEGMENTS_DIR/${SEGMENT_PREFIX}_$i.mp4"
        else
            AUDIO_FILE="$CONTENT_DIR/audio_${i}${AUDIO_SUFFIX}.wav"
            SEGMENT_FILE="$SEGMENTS_DIR/${SEGMENT_PREFIX}_$i.mp4"
        fi
        
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
            return 1
        fi
    done
    
    if [ $SEGMENTS_CREATED -eq 0 ]; then
        echo "❌ No segments were created for $LANGUAGE_LABEL. Please check your input files."
        return 1
    fi
    
    echo ""
    echo "Step 2: Creating concatenation list for $LANGUAGE_LABEL..."
    
    # Step 2: Create concatenation list file
    CONCAT_LIST="$SEGMENTS_DIR/concat_list${AUDIO_SUFFIX}.txt"
    > "$CONCAT_LIST"  # Clear/create the file
    
    for i in $(seq 1 "$MAX_SEGMENT"); do
        SEGMENT_FILE="$SEGMENTS_DIR/${SEGMENT_PREFIX}_$i.mp4"
        if [ -f "$SEGMENT_FILE" ]; then
            # Use absolute path for concat file to avoid path issues
            echo "file '$SEGMENT_FILE'" >> "$CONCAT_LIST"
        fi
    done
    
    echo "  ✅ Concatenation list created with $(wc -l < "$CONCAT_LIST") segments"
    echo ""
    
    # Step 3: Concatenate all segments
    echo "Step 3: Concatenating all segments into final video for $LANGUAGE_LABEL..."
    FINAL_OUTPUT="$OUTPUT_DIR/${TIMESTAMP}.mp4"
    
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
        return 0
    else
        echo ""
        echo "❌ Error during concatenation for $LANGUAGE_LABEL"
        return 1
    fi
}

# Process default language (Mandarin - no suffix)
if process_language "" "Mandarin" "$MANDARIN_CI_DIR"; then
    echo ""
fi

# Process Spanish language (_es suffix)
if process_language "_es" "Spanish" "$SPANISH_CI_DIR"; then
    echo ""
fi

echo "🎉 Process complete!"
