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

def find_max_segment_number(content_dir):
    """Find the highest segment number by scanning audio files."""
    audio_files = list(content_dir.glob("audio_*.wav"))
    if not audio_files:
        return 0
    
    max_segment = 0
    for audio_file in audio_files:
        # Extract number from filename (e.g., audio_10.wav -> 10)
        try:
            segment_num = int(audio_file.stem.split('_')[1])
            if segment_num > max_segment:
                max_segment = segment_num
        except (ValueError, IndexError):
            continue
    
    return max_segment

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
    
    segments_dir = content_dir / "segments"
    output_dir = content_dir / "output"
    
    # Create directories
    segments_dir.mkdir(exist_ok=True)
    output_dir.mkdir(exist_ok=True)
    
    print("🎬 Starting video creation process...")
    print(f"📁 Content directory: {content_dir}")
    print()
    
    # Auto-detect number of segments
    max_segment = find_max_segment_number(content_dir)
    if max_segment == 0:
        print("❌ Error: No audio files found (audio_*.wav) in content directory")
        sys.exit(1)
    
    print(f"📊 Found {max_segment} segment(s)")
    print()
    
    # Step 1: Generate individual video segments
    print("Step 1: Creating individual video segments...")
    segments_created = []
    
    for i in range(1, max_segment + 1):
        image_file = content_dir / f"image_{i}.png"
        audio_file = content_dir / f"audio_{i}.wav"
        segment_file = segments_dir / f"segment_{i}.mp4"
        
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
            sys.exit(1)
    
    if not segments_created:
        print("❌ No segments were created. Please check your input files.")
        sys.exit(1)
    
    print()
    print("Step 2: Creating concatenation list...")
    
    # Step 2: Create concatenation list file
    concat_list = segments_dir / "concat_list.txt"
    with open(concat_list, "w") as f:
        for segment_file in segments_created:
            # Use absolute path for concat file
            f.write(f"file '{segment_file.absolute()}'\n")
    
    print(f"  ✅ Concatenation list created with {len(segments_created)} segments")
    print()
    
    # Step 3: Concatenate all segments
    print("Step 3: Concatenating all segments into final video...")
    final_output = output_dir / "final_video.mp4"
    
    cmd = [
        "ffmpeg",
        "-f", "concat",
        "-safe", "0",
        "-i", str(concat_list),
        "-c", "copy",
        "-y",
        str(final_output)
    ]
    
    if run_ffmpeg_command(cmd, "concatenating segments"):
        print()
        print(f"✅ SUCCESS! Final video created: {final_output}")
        print()
        
        # Get file size
        if final_output.exists():
            size_mb = final_output.stat().st_size / (1024 * 1024)
            print(f"📊 File size: {size_mb:.2f} MB")
        
        print()
        print("🎉 Process complete!")
    else:
        print()
        print("❌ Error during concatenation")
        sys.exit(1)

if __name__ == "__main__":
    main()

