#!/bin/bash
# Usage: ./mac_expand.sh <prefix-mac> <suffix-int>
# Example: ./mac_expand.sh 5c-25-73-f1-40-00 1012

PREFIX_MAC="$1"
SUFFIX="$2"
PREFIX_BITS=38
LEFTOVER=$((48 - PREFIX_BITS))

# Convert dash-separated MAC to integer
mac_hex=$(echo "$PREFIX_MAC" | tr -d '-')
mac_int=$((16#$mac_hex))

# OR the suffix into the lower bits
full_mac=$(( mac_int | (SUFFIX & ((1 << LEFTOVER) - 1)) ))

# Format as MAC address
printf "%012x\n" "$full_mac" | sed 's/\(..\)/\1-/g; s/-$//'
