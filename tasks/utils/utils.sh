#!/bin/bash
# Shared utility functions for task.yaml files

# Function to format byte size using shell arithmetic
format_size() {
    local size_bytes="$1"
    
    # Convert to appropriate unit
    if [ $size_bytes -ge 1073741824 ]; then
        # >= 1GB, show in GB
        local size_gb=$((size_bytes / 1024 / 1024 / 1024))
        local remainder_mb=$(((size_bytes % (1024 * 1024 * 1024)) / 1024 / 1024))
        local decimal_part=$((remainder_mb * 100 / 1024))
        echo "${size_gb}.${decimal_part} GB"
    elif [ $size_bytes -ge 1048576 ]; then
        # >= 1MB, show in MB
        local size_mb=$((size_bytes / 1024 / 1024))
        local remainder_kb=$(((size_bytes % (1024 * 1024)) / 1024))
        local decimal_part=$((remainder_kb * 100 / 1024))
        echo "${size_mb}.${decimal_part} MB"
    elif [ $size_bytes -ge 1024 ]; then
        # >= 1KB, show in KB
        local size_kb=$((size_bytes / 1024))
        local remainder_bytes=$((size_bytes % 1024))
        local decimal_part=$((remainder_bytes * 100 / 1024))
        echo "${size_kb}.${decimal_part} KB"
    else
        # < 1KB, show in bytes
        echo "${size_bytes} bytes"
    fi
}

# Function to format file sizes using shell arithmetic
format_file_size() {
    local file_path="$1"
    local file_size=$(stat -c%s "$file_path" 2>/dev/null || echo "0")
    format_size "$file_size"
}

