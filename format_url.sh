#!/bin/bash

# Function to format URL with line breaks and indents after each parameter
format_url() {
    # Add newline before output
    echo
    
    # Get the URL from arguments or stdin
    local url
    if [ $# -gt 0 ]; then
        url="$1"
    else
        read -r url
    fi
    
    # Remove any surrounding quotes, newlines, and leading spaces
    url=$(echo "$url" | tr -d '\n' | sed -e 's/^[[:space:]]*//' -e 's/^"//' -e 's/"$//')
    
    # Split URL into base and query parts
    local base_url="${url%%\?*}"
    local query="${url#*\?}"
    
    # If there's no query string, just output the URL
    if [ "$query" = "$url" ]; then
        echo "$url"
        return 0
    fi
    
    # Output the base URL
    echo "$base_url"
    
    # Split and output each query parameter on a new line with consistent indentation
    # First parameter gets ? prefix, rest get & prefix
    echo "$query" | sed 's/&/\
  &/g' | sed '1s/^/  ?/'
}

# Check if we're being piped to
if [ ! -t 0 ]; then
    # Read from pipe
    while IFS= read -r line || [ -n "$line" ]; do
        format_url "$line"
    done
else
    # Read from arguments or prompt
    if [ $# -eq 0 ]; then
        echo "Enter URL to format (press Ctrl+D when done):"
        while IFS= read -r line; do
            format_url "$line"
        done
    else
        # Handle all arguments as separate URLs
        for url in "$@"; do
            format_url "$url"
        done
    fi
fi

exit 0
