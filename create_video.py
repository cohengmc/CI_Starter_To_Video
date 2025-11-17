#!/usr/bin/env python3
"""
Script to create MP4 video from segmented audio and images using FFmpeg.
This script creates individual segments and then concatenates them.

Usage:
    python3 create_video.py [content_directory]
    
    If content_directory is not provided, uses current directory.
"""

import os
import subprocess
import sys
import glob
from pathlib import Path
from datetime import datetime

def run_ffmpeg_command(cmd, description):
    """Run an FFmpeg command and handle errors."""
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=True
        )
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ Error: {description}")
        print(f"   FFmpeg error: {e.stderr}")
        return False
    except FileNotFoundError:
        print("❌ Error: FFmpeg not found. Please install FFmpeg first.")
        print("   Install with: brew install ffmpeg")
        sys.exit(1)

def find_max_segment_number(content_dir, audio_suffix=""):
    """Find the highest segment number by scanning audio files."""
    if audio_suffix:
        audio_files = list(content_dir.glob(f"audio_*{audio_suffix}.wav"))
    else:
        # Get all audio files and exclude _es files
        all_audio = list(content_dir.glob("audio_*.wav"))
        audio_files = [f for f in all_audio if not f.stem.endswith("_es")]
    
    if not audio_files:
        return 0
    
    max_segment = 0
    for audio_file in audio_files:
        # Extract number from filename (e.g., audio_10.wav -> 10, audio_10_es.wav -> 10)
        try:
            parts = audio_file.stem.split('_')
            segment_num = int(parts[1])
            if segment_num > max_segment:
                max_segment = segment_num
        except (ValueError, IndexError):
            continue
    
    return max_segment

def process_language(content_dir, segments_dir, output_dir, timestamp, audio_suffix="", language_label="default language"):
    """Process audio files for a specific language variant."""
    
    # Find max segment number
    max_segment = find_max_segment_number(content_dir, audio_suffix)
    if max_segment == 0:
        return False
    
    print(f"📊 Found {max_segment} segment(s) for {language_label}")
    print()
    
    # Step 1: Generate individual video segments
    print(f"Step 1: Creating individual video segments for {language_label}...")
    segments_created = []
    segment_prefix = "segment" if not audio_suffix else f"segment{audio_suffix}"
    
    for i in range(1, max_segment + 1):
        image_file = content_dir / f"image_{i}.png"
        if audio_suffix:
            audio_file = content_dir / f"audio_{i}{audio_suffix}.wav"
        else:
            audio_file = content_dir / f"audio_{i}.wav"
        segment_file = segments_dir / f"{segment_prefix}_{i}.mp4"
        
        # Check if files exist
        if not image_file.exists():
            print(f"⚠️  Warning: {image_file.name} not found, skipping segment {i}")
            continue
        if not audio_file.exists():
            print(f"⚠️  Warning: {audio_file.name} not found, skipping segment {i}")
            continue
        
        print(f"  Creating segment {i}/{max_segment}...")
        
        # FFmpeg command to create segment
        cmd = [
            "ffmpeg",
            "-loop", "1",
            "-i", str(image_file),
            "-i", str(audio_file),
            "-c:v", "libx264",
            "-tune", "stillimage",
            "-pix_fmt", "yuv420p",
            "-c:a", "aac",
            "-b:a", "192k",
            "-shortest",
            "-y",  # Overwrite output file
            str(segment_file)
        ]
        
        if run_ffmpeg_command(cmd, f"creating segment {i}"):
            print(f"  ✅ Segment {i} created successfully")
            segments_created.append(segment_file)
        else:
            print(f"  ❌ Error creating segment {i}")
            return False
    
    if not segments_created:
        print(f"❌ No segments were created for {language_label}. Please check your input files.")
        return False
    
    print()
    print(f"Step 2: Creating concatenation list for {language_label}...")
    
    # Step 2: Create concatenation list file
    concat_list = segments_dir / f"concat_list{audio_suffix}.txt"
    with open(concat_list, "w") as f:
        for segment_file in segments_created:
            # Use absolute path for concat file
            f.write(f"file '{segment_file.absolute()}'\n")
    
    print(f"  ✅ Concatenation list created with {len(segments_created)} segments")
    print()
    
    # Step 3: Concatenate all segments
    print(f"Step 3: Concatenating all segments into final video for {language_label}...")
    final_output = output_dir / f"{timestamp}.mp4"
    
    cmd = [
        "ffmpeg",
        "-f", "concat",
        "-safe", "0",
        "-i", str(concat_list),
        "-c", "copy",
        "-y",
        str(final_output)
    ]
    
    if run_ffmpeg_command(cmd, f"concatenating segments for {language_label}"):
        print()
        print(f"✅ SUCCESS! Final video created: {final_output}")
        print()
        
        # Get file size
        if final_output.exists():
            size_mb = final_output.stat().st_size / (1024 * 1024)
            print(f"📊 File size: {size_mb:.2f} MB")
        
        return True
    else:
        print()
        print(f"❌ Error during concatenation for {language_label}")
        return False

def main():
    # Get content directory from argument or use current directory
    if len(sys.argv) > 1:
        content_dir = Path(sys.argv[1]).absolute()
    else:
        content_dir = Path.cwd()
    
    # Validate content directory exists
    if not content_dir.exists() or not content_dir.is_dir():
        print(f"❌ Error: Content directory does not exist: {content_dir}")
        sys.exit(1)
    
    # Set output folders to Desktop
    mandarin_ci_dir = Path("/Users/geoffreycohen/Desktop/Mandarin CI")
    spanish_ci_dir = Path("/Users/geoffreycohen/Desktop/Spanish CI")
    
    # Create output directories
    mandarin_ci_dir.mkdir(exist_ok=True)
    spanish_ci_dir.mkdir(exist_ok=True)
    
    segments_dir = content_dir / "segments"
    
    # Create directory for segments
    segments_dir.mkdir(exist_ok=True)
    
    # Generate timestamp for output filename
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    
    print("🎬 Starting video creation process...")
    print(f"📁 Content directory: {content_dir}")
    print()
    
    # Process default language (Mandarin - no suffix)
    if find_max_segment_number(content_dir, "") > 0:
        process_language(content_dir, segments_dir, mandarin_ci_dir, timestamp, "", "Mandarin")
        print()
    
    # Process Spanish language (_es suffix)
    if find_max_segment_number(content_dir, "_es") > 0:
        process_language(content_dir, segments_dir, spanish_ci_dir, timestamp, "_es", "Spanish")
        print()
    
    print("🎉 Process complete!")

if __name__ == "__main__":
    main()
