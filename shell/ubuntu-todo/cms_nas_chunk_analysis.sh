#!/bin/zsh
# CMS NAS Chunk File Analysis Script
# Usage: cms_nas_chunk_analysis.sh

nas_dir="/mnt/nas1/telemetry"
tus=(tu1-A3EV47 tu2-A3EV4D tu3-A3JWG4 tu4-A3JWG6)
topics=(oil rlte_actual rlte_detail temp vibration vibrationtemp)

echo "CMS NAS Chunk File Analysis (Fr 16.01 – Wed 23.01.2026)"
echo "NAS directory: $nas_dir"
echo

for tu in $tus; do
  echo "# $tu"
  for topic in $topics; do
    echo "## Topic: $topic"
    dir="$nas_dir/$tu/2026/01"
    # Total chunk files
    total=$(find "$dir" -type f -name "$topic-chunk-*.pb*" | wc -l)
    # Sent chunk files
    sent=$(find "$dir" -type f -name "$topic-chunk-*.pb.sent" | wc -l)
    # Failed chunk files
    failed=$(find "$dir" -type f -name "$topic-chunk-*.pb" | wc -l)
    # Time range sent
    first_sent=$(find "$dir" -type f -name "$topic-chunk-*.pb.sent" | sort | head -n1 | xargs -r basename)
    last_sent=$(find "$dir" -type f -name "$topic-chunk-*.pb.sent" | sort | tail -n1 | xargs -r basename)
    # Time range failed
    first_failed=$(find "$dir" -type f -name "$topic-chunk-*.pb" | sort | head -n1 | xargs -r basename)
    last_failed=$(find "$dir" -type f -name "$topic-chunk-*.pb" | sort | tail -n1 | xargs -r basename)
    echo "- Total chunk files: $total"
    echo "- Sent chunk files (.pb.sent): $sent"
    echo "- Failed chunk files (.pb): $failed"
    echo "- Sent time range: $first_sent – $last_sent"
    echo "- Failed time range: $first_failed – $last_failed"
    echo
  done
  echo "---"
done
