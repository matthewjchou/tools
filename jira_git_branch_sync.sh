#!/bin/bash

# Script to show overview of local git branches and their associated Jira issues
# Usage: ./jira_git_branch_sync.sh [directory] [email]
# Requires: JIRA_API_TOKEN environment variable to be set

set -e

# Configuration
JIRA_BASE_URL="https://sedona.atlassian.net"
JIRA_API_ENDPOINT="/rest/api/2/issue"

# Get directory parameter or use current directory
GIT_DIR="${1:-.}"

# Get email parameter or use git config
if [ -n "$2" ]; then
    JIRA_EMAIL="$2"
else
    JIRA_EMAIL=$(git -C "$GIT_DIR" config user.email 2>/dev/null || echo "")
    if [ -z "$JIRA_EMAIL" ]; then
        echo "Error: Could not determine email from git config"
        echo "Please provide email as second parameter: ./jira_git_branch_sync.sh [directory] [email]"
        exit 1
    fi
fi

# Check if directory exists
if [ ! -d "$GIT_DIR" ]; then
    echo "Error: Directory '$GIT_DIR' does not exist"
    exit 1
fi

# Check if it's a git repository
if [ ! -d "$GIT_DIR/.git" ]; then
    echo "Error: '$GIT_DIR' is not a git repository"
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed"
    echo "Please install it with: brew install jq"
    exit 1
fi

# Check if JIRA_API_TOKEN is set
if [ -z "$JIRA_API_TOKEN" ]; then
    echo "Error: JIRA_API_TOKEN environment variable is not set"
    echo "Please set it with: export JIRA_API_TOKEN='your_token_here'"
    exit 1
fi

echo "Using email: $JIRA_EMAIL"

# Function to extract Jira issue key from branch name
extract_jira_key() {
    local branch_name="$1"
    # Match pattern: 3-4 uppercase letters, hyphen, then numbers
    echo "$branch_name" | grep -oE '[A-Z]{3,4}-[0-9]+' | head -1
}

# Function to get Jira issue details
get_jira_issue() {
    local issue_key="$1"
    local url="${JIRA_BASE_URL}${JIRA_API_ENDPOINT}/${issue_key}"
    
    # Call Jira API with basic auth (email:api_token)
    local response=$(curl -s \
        -u "${JIRA_EMAIL}:${JIRA_API_TOKEN}" \
        -H "Accept: application/json" \
        "$url")
    
    echo "$response"
}

# Function to parse Jira response
parse_jira_response() {
    local response="$1"
    
    # Use jq to parse JSON response
    local title=$(echo "$response" | jq -r '.fields.summary // "N/A"')
    local status=$(echo "$response" | jq -r '.fields.status.name // "N/A"')
    
    echo "${title}|${status}"
}

# Main script
echo "Fetching local git branches and associated Jira issues from: $GIT_DIR"
echo ""

# Arrays to store data
declare -a branches
declare -a jira_keys
declare -a jira_titles
declare -a jira_statuses

# Get all local branches (excluding current branch indicator)
while IFS= read -r branch; do
    # Remove leading/trailing whitespace and asterisk
    branch=$(echo "$branch" | sed 's/^[* ]*//;s/ *$//')
    
    # Skip empty lines
    [ -z "$branch" ] && continue
    
    # Extract Jira key
    jira_key=$(extract_jira_key "$branch")
    
    if [ -n "$jira_key" ]; then
        branches+=("$branch")
        jira_keys+=("$jira_key")
        
        # Get Jira issue details
        echo "Fetching $jira_key..." >&2
        response=$(get_jira_issue "$jira_key")
        
        # Parse response
        parsed=$(parse_jira_response "$response")
        title=$(echo "$parsed" | cut -d'|' -f1)
        status=$(echo "$parsed" | cut -d'|' -f2)
        
        # Handle empty responses
        if [ -z "$title" ] || [ "$title" = "N/A" ]; then
            title="Unable to fetch"
        fi
        if [ -z "$status" ] || [ "$status" = "N/A" ]; then
            status="Unknown"
        fi
        
        jira_titles+=("$title")
        jira_statuses+=("$status")
    fi
done < <(git -C "$GIT_DIR" branch)

echo "" >&2

# Check if any branches were found
if [ ${#branches[@]} -eq 0 ]; then
    echo "No branches with Jira issue keys found."
    exit 0
fi

# Print formatted table
printf "%-50s | %-60s | %-20s\n" "BRANCH NAME" "JIRA TITLE" "STATUS"
printf "%-50s-+-%-60s-+-%-20s\n" "$(printf '%*s' 50 '' | tr ' ' '-')" "$(printf '%*s' 60 '' | tr ' ' '-')" "$(printf '%*s' 20 '' | tr ' ' '-')"

# Print each row
for i in "${!branches[@]}"; do
    branch="${branches[$i]}"
    title="${jira_titles[$i]}"
    status="${jira_statuses[$i]}"
    
    # Truncate long values
    if [ ${#branch} -gt 50 ]; then
        branch="${branch:0:47}..."
    fi
    if [ ${#title} -gt 60 ]; then
        title="${title:0:57}..."
    fi
    if [ ${#status} -gt 20 ]; then
        status="${status:0:17}..."
    fi
    
    printf "%-50s | %-60s | %-20s\n" "$branch" "$title" "$status"
done

# Summary
echo ""
echo "Total branches with Jira issues: ${#branches[@]}"
