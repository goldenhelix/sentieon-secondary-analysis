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

# ---------------------------------------------------------------------------
# Memory diagnostics (cgroup v2 aware, v1 fallback)
#
# These helpers write an INDEPENDENT memory timeline into the task log so that
# an OOM / host-pressure event stays diagnosable even when the VSW3
# container-stats sidecar drops its handshake ("Failed to get container stats
# ... Timed out while waiting for handshake") -- which is itself a symptom of
# the container dying under memory pressure. All reads are best-effort and
# never fail the caller (safe under `set -euo pipefail`).
# ---------------------------------------------------------------------------
_CGV2="/sys/fs/cgroup"

# Container memory hard limit in bytes. Falls back to host MemTotal when the
# cgroup reports "max" (no limit) or the interface is unavailable.
mem_limit_bytes() {
    local v
    if [ -r "${_CGV2}/memory.max" ]; then
        v=$(cat "${_CGV2}/memory.max" 2>/dev/null)
        if [ "$v" != "max" ] && [ -n "$v" ]; then echo "$v"; return 0; fi
    elif [ -r /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then
        v=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null)
        if [ -n "$v" ]; then echo "$v"; return 0; fi
    fi
    awk '/^MemTotal:/{print $2*1024}' /proc/meminfo 2>/dev/null || echo 0
}

# Current cgroup memory usage in bytes.
mem_current_bytes() {
    if [ -r "${_CGV2}/memory.current" ]; then
        cat "${_CGV2}/memory.current" 2>/dev/null || echo 0
    elif [ -r /sys/fs/cgroup/memory/memory.usage_in_bytes ]; then
        cat /sys/fs/cgroup/memory/memory.usage_in_bytes 2>/dev/null || echo 0
    else
        echo 0
    fi
}

# Peak cgroup memory usage in bytes (cgroup v2, kernel >= 5.19). 0 if absent.
mem_peak_bytes() {
    if [ -r "${_CGV2}/memory.peak" ]; then
        cat "${_CGV2}/memory.peak" 2>/dev/null || echo 0
    else
        echo 0
    fi
}

# cgroup OOM-kill count (oom_kill + oom_group_kill). 0 if unavailable.
oom_kills() {
    local k g
    k=0; g=0
    if [ -r "${_CGV2}/memory.events" ]; then
        k=$(awk '/^oom_kill /{print $2}'       "${_CGV2}/memory.events" 2>/dev/null)
        g=$(awk '/^oom_group_kill /{print $2}' "${_CGV2}/memory.events" 2>/dev/null)
    fi
    echo $(( ${k:-0} + ${g:-0} ))
}

# Memory pressure (PSI) "some" avg10 -- percent of time stalled on memory in the
# last 10s. High values (approaching 100) mean reclaim thrash. Empty if N/A.
mem_pressure_avg10() {
    [ -r "${_CGV2}/memory.pressure" ] || return 0
    awk '/^some /{for(i=1;i<=NF;i++) if($i ~ /^avg10=/){sub("avg10=","",$i); print $i}}' \
        "${_CGV2}/memory.pressure" 2>/dev/null || true
}

# One-line memory snapshot. Usage: mem_report "<label>"
mem_report() {
    local label cur lim peak oom psi pct
    label="${1:-mem}"
    cur=$(mem_current_bytes); lim=$(mem_limit_bytes); peak=$(mem_peak_bytes)
    oom=$(oom_kills); psi=$(mem_pressure_avg10)
    pct="n/a"
    if [[ "${cur:-}" =~ ^[0-9]+$ ]] && [[ "${lim:-}" =~ ^[0-9]+$ ]] && [ "${lim}" -gt 0 ]; then
        pct="$(( cur * 100 / lim ))%"
    fi
    printf '📊 [mem:%s] used=%s peak=%s limit=%s (%s) oom_kills=%s pressure10=%s\n' \
        "$label" "$(format_size "${cur:-0}")" "$(format_size "${peak:-0}")" \
        "$(format_size "${lim:-0}")" "$pct" "${oom:-0}" "${psi:-n/a}"
}

# Background memory sampler. Usage: mem_monitor_start [interval_sec]
# Stores the sampler PID in _MEM_MONITOR_PID. Output goes to stdout (and thus
# to the tee'd task log), so it survives a stats-sidecar handshake failure.
mem_monitor_start() {
    local interval="${1:-15}"
    ( set +e
      while true; do
          mem_report "watch"
          # Top 3 processes by RSS for attribution (bwa vs util sort vs driver)
          ps -eo rss=,comm= 2>/dev/null | sort -rn | head -3 | \
            awk '{printf "   \xe2\x86\xb3 %-16s %d MB\n", $2, $1/1024}' 2>/dev/null || true
          sleep "$interval"
      done ) &
    _MEM_MONITOR_PID=$!
    echo "Started memory monitor (pid ${_MEM_MONITOR_PID}, every ${interval}s)"
}

mem_monitor_stop() {
    if [ -n "${_MEM_MONITOR_PID:-}" ]; then
        kill "${_MEM_MONITOR_PID}" 2>/dev/null || true
        wait "${_MEM_MONITOR_PID}" 2>/dev/null || true
        _MEM_MONITOR_PID=""
    fi
}

