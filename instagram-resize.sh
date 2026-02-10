#!/bin/bash

# Parse command line arguments
source="$1"
dest="$2"
color="$3"

# Prompt for source if not provided
if [ -z "$source" ]; then
    read -p "Enter the source folder path [. for current directory, default: .]: " source
    if [ -z "$source" ]; then
        source="."
    fi
fi

# Prompt for destination if not provided
if [ -z "$dest" ]; then
    read -p "Enter the destination folder path [. for current directory, default: ./Resized/]: " dest
    if [ -z "$dest" ]; then
        dest="./Resized/"
    fi
fi

# Prompt for color if not provided
if [ -z "$color" ]; then
    read -p "Enter the background color [default: white]: " color
    if [ -z "$color" ]; then
        color="white"
    fi
fi

# Create destination directory if it doesn't exist
if [ ! -d "$dest" ]; then
    mkdir -p "$dest"
fi

# Process all jpg files in the source directory
for file in "$source"/*.jpg; do
    # Skip if no jpg files found
    if [ ! -f "$file" ]; then
        continue
    fi
    
    # Get filename without path and extension
    filename=$(basename "$file")
    basename="${filename%.*}"
    extension="${filename##*.}"
    
    # Construct output path
    output="${dest}${basename}-1080x1080.${extension}"
    
    echo "$file -> $output"
    magick -background "$color" -gravity center "$file" -resize 1080x1080 -extent 1080x1080 "$output"
done
