# Video Creation from Segmented Audio and Images

Reusable scripts to create MP4 videos from segmented audio files and corresponding images.

## Prerequisites

You need **FFmpeg** installed on your system.

### Install FFmpeg on macOS:
```bash
brew install ffmpeg
```

### Verify installation:
```bash
ffmpeg -version
```

## Usage

These scripts can be run from any location and will process a content folder containing your audio and image files.

### Option 1: Bash Script (Recommended for macOS/Linux)

**From anywhere:**
```bash
/path/to/CI_Starter_To_Video/create_video.sh /path/to/content_folder
```

**Or from within the content directory:**
```bash
cd /path/to/content_folder
/path/to/CI_Starter_To_Video/create_video.sh .
```

**Or from the project root:**
```bash
cd /path/to/CI_Starter_To_Video
./create_video.sh /path/to/content_folder
```

### Option 2: Python Script

**From anywhere:**
```bash
python3 /path/to/CI_Starter_To_Video/create_video.py /path/to/content_folder
```

**Or from within the content directory:**
```bash
cd /path/to/content_folder
python3 /path/to/CI_Starter_To_Video/create_video.py .
```

**Or from the project root:**
```bash
cd /path/to/CI_Starter_To_Video
python3 create_video.py /path/to/content_folder
```

## Content Folder Structure

Your content folder should contain:
- `audio_1.wav`, `audio_2.wav`, ... `audio_N.wav` - Audio files (Mandarin)
- `audio_1_es.wav`, `audio_2_es.wav`, ... `audio_N_es.wav` - Audio files (Spanish, optional)
- `image_1.png`, `image_2.png`, ... `image_N.png` - Image files
- Optional: `transcripts.txt` - For reference

The scripts will automatically detect the number of segments by finding the highest numbered audio file. If Spanish audio files (with `_es` suffix) are present, the script will create separate videos for both languages.

## How It Works

The scripts follow a two-step FFmpeg workflow:

1. **Segment Generation**: Creates individual MP4 segments, each combining one image with its corresponding audio file. The duration of each segment matches the length of its audio file.

2. **Concatenation**: Joins all segments together into a single final video file without re-encoding (fast and lossless).

## Output

The scripts create the following structure:

**In your content folder:**
```
content_folder/
├── audio_1.wav ... audio_N.wav    # Your input files (Mandarin)
├── audio_1_es.wav ... audio_N_es.wav  # Your input files (Spanish, optional)
├── image_1.png ... image_N.png     # Your input files
└── segments/                       # Created during execution
    ├── segment_1.mp4 ... segment_N.mp4
    ├── segment_es_1.mp4 ... segment_es_N.mp4 (if Spanish audio exists)
    ├── concat_list.txt
    └── concat_list_es.txt (if Spanish audio exists)
```

**On Desktop:**
```
~/Desktop/
├── Mandarin CI/                    # Final MP4 files (Mandarin)
│   └── YYYYMMDD_HHMMSS.mp4         # Timestamped output
└── Spanish CI/                     # Final MP4 files (Spanish)
    └── YYYYMMDD_HHMMSS.mp4         # Timestamped output (if Spanish audio exists)
```

**Note:** Only the final concatenated MP4 files are saved to the `Mandarin CI` and `Spanish CI` folders on your Desktop. Intermediate segments remain in the content folder's `segments/` directory.

## Technical Details

- **Video Codec**: H.264 (libx264) with `stillimage` tune for optimal compression of static images
- **Pixel Format**: yuv420p (maximum compatibility)
- **Audio Codec**: AAC at 192 kbps
- **Concatenation**: Uses FFmpeg's concat demuxer with stream copy (no re-encoding)
- **Auto-detection**: Automatically finds the number of segments by scanning audio files
- **Multi-language Support**: Detects and processes both Mandarin (default) and Spanish (`_es` suffix) audio files
- **Output Filenames**: Uses timestamp format `YYYYMMDD_HHMMSS.mp4` for unique file naming
- **Output Locations**: 
  - Mandarin videos → `~/Desktop/Mandarin CI/` folder
  - Spanish videos → `~/Desktop/Spanish CI/` folder

## Examples

### Example 1: Process a content folder (from project root)
```bash
cd /Users/geoffreycohen/Documents/dev/CI_Starter_To_Video
./create_video.sh /Users/geoffreycohen/Downloads/content_00b73250
```

### Example 2: Process current directory (from content folder)
```bash
cd /Users/geoffreycohen/Downloads/content_00b73250
/Users/geoffreycohen/Documents/dev/CI_Starter_To_Video/create_video.sh .
```

### Example 3: Using Python script
```bash
cd /Users/geoffreycohen/Documents/dev/CI_Starter_To_Video
python3 create_video.py /Users/geoffreycohen/Downloads/content_00b73250
```

## Troubleshooting

- **FFmpeg not found**: Install FFmpeg using `brew install ffmpeg` (macOS) or your system's package manager
- **Missing files**: Ensure all audio_*.wav and image_*.png files are present in the content folder
- **Permission errors**: Make sure scripts are executable (`chmod +x create_video.sh`)
- **No segments found**: Check that your audio files follow the naming pattern `audio_1.wav`, `audio_2.wav`, etc.

## Replicating for Multiple Content Folders

To process multiple content folders, simply run the script with different paths:

```bash
# From project root
cd /path/to/CI_Starter_To_Video

# Process first content folder
./create_video.sh /path/to/content_folder_1

# Process second content folder
./create_video.sh /path/to/content_folder_2

# Process third content folder
./create_video.sh /path/to/content_folder_3
```

Each content folder will have its own `segments/` directory created automatically. All final MP4 files will be saved to the `Mandarin CI/` and `Spanish CI/` folders on your Desktop with timestamped filenames, so multiple runs won't overwrite previous outputs.

