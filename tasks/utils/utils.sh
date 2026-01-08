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

# Function to copy files with progress bar, size reporting, and disk space monitoring
# Usage: copy_with_progress <dest_dir> <file1> [file2] [file3] ...
# Helper function to format numeric byte values
format_bytes() {
    local bytes="$1"
    local unit="${2:-}"  # Optional: "KB", "MB", or "GB" - use empty string if not provided
    
    # If specific unit is requested, format in that unit
    if [ -n "$unit" ]; then
        case "$unit" in
            "KB")
                local size_kb=$((bytes / 1024))
                local remainder_bytes=$((bytes % 1024))
                local decimal_part=$((remainder_bytes * 100 / 1024))
                echo "${size_kb}.${decimal_part}"
                ;;
            "MB")
                local size_mb=$((bytes / 1024 / 1024))
                local remainder_kb=$(((bytes % (1024 * 1024)) / 1024))
                local decimal_part=$((remainder_kb * 100 / 1024))
                echo "${size_mb}.${decimal_part}"
                ;;
            "GB")
                local size_gb=$((bytes / 1024 / 1024 / 1024))
                local remainder_mb=$(((bytes % (1024 * 1024 * 1024)) / 1024 / 1024))
                local decimal_part=$((remainder_mb * 100 / 1024))
                echo "${size_gb}.${decimal_part}"
                ;;
            *)
                echo "0.0"
                ;;
        esac
    else
        # Auto-select appropriate unit
        if [ $bytes -ge 1073741824 ]; then
            # >= 1GB, show in GB
            local size_gb=$((bytes / 1024 / 1024 / 1024))
            local remainder_mb=$(((bytes % (1024 * 1024 * 1024)) / 1024 / 1024))
            local decimal_part=$((remainder_mb * 100 / 1024))
            echo "${size_gb}.${decimal_part} GB"
        elif [ $bytes -ge 1048576 ]; then
            # >= 1MB, show in MB
            local size_mb=$((bytes / 1024 / 1024))
            local remainder_kb=$(((bytes % (1024 * 1024)) / 1024))
            local decimal_part=$((remainder_kb * 100 / 1024))
            echo "${size_mb}.${decimal_part} MB"
        elif [ $bytes -ge 1024 ]; then
            # >= 1KB, show in KB
            local size_kb=$((bytes / 1024))
            local remainder_bytes=$((bytes % 1024))
            local decimal_part=$((remainder_bytes * 100 / 1024))
            echo "${size_kb}.${decimal_part} KB"
        else
            # < 1KB, show in bytes
            echo "${bytes} bytes"
        fi
    fi
}

copy_with_progress() {
    local dest_dir="$1"
    shift
    local files=("$@")
    local total_files=${#files[@]}
    local current_file=0
    local total_size_copied=0
    
    # Calculate total input size before copying
    local total_input_size=0
    for file in "${files[@]}"; do
        total_input_size=$((total_input_size + $(stat -c%s "$file" 2>/dev/null || echo "0")))
    done
    
    echo "Copying $total_files files ($(format_bytes "$total_input_size")) to $dest_dir..."
    echo "================================================"
    
    for file in "${files[@]}"; do
        current_file=$((current_file + 1))
        local filename=$(basename "$file")
        local dest_path="$dest_dir/$filename"
        
        echo "[$current_file/$total_files] Copying: $filename ($(format_file_size "$file"))"
        
        # Copy with progress bar using pv
        if command -v pv >/dev/null 2>&1; then
            pv "$file" > "$dest_path"
        else
            # Fallback to cp if pv is not available
            cp "$file" "$dest_path"
        fi
        
        # Verify copy and get actual copied size
        local copied_size=$(stat -c%s "$dest_path" 2>/dev/null || echo "0")
        total_size_copied=$((total_size_copied + copied_size))
        
        echo "✓ Copied: $filename ($(format_file_size "$dest_path"))"
        echo "----------------------------------------"
    done
    
    echo "================================================"
    echo "✓ All files copied successfully!"
    echo "Total size copied: $(format_bytes "$total_size_copied")"
    
    # Show remaining disk space
    if command -v df >/dev/null 2>&1; then
        local dest_mount=$(df "$dest_dir" | tail -1 | awk '{print $1}')
        local available_space=$(df -h "$dest_dir" | tail -1 | awk '{print $4}')
        local used_percent=$(df "$dest_dir" | tail -1 | awk '{print $5}')
        echo "Remaining disk space on $dest_mount: $available_space ($used_percent used)"
    fi
    echo "================================================"
}

