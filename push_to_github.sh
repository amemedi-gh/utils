#!/bin/bash

# Configuration
GITHUB_DOMAIN="github.yourcompany.com"  # Change this to your GitHub domain
GITHUB_ORG="your-org-name"              # Change this to your GitHub org name
GITHUB_TOKEN="your-github-token-here"   # Change this to your GitHub Personal Access Token
BASE_DIR="github-repos/${GITHUB_ORG}"   # Base directory containing all repos
DEFAULT_BRANCH="main"

# Validate base directory exists
if [ ! -d "$BASE_DIR" ]; then
    echo "Error: Base directory '$BASE_DIR' not found"
    exit 1
fi

# Check if token is set
if [[ "$GITHUB_TOKEN" == "your-github-token-here" ]]; then
    echo "Error: Please update GITHUB_TOKEN at the top of this script!"
    exit 1
fi

echo "Base directory: $BASE_DIR"
echo "GitHub domain: $GITHUB_DOMAIN"
echo "GitHub org: $GITHUB_ORG"
echo "Default branch: $DEFAULT_BRANCH"
echo ""

# Counters
total_repos=0
successful_pushes=0
failed_pushes=0
declare -a failed_repos

# Loop through each directory in the org folder
for repo_dir in "$BASE_DIR"/*; do
    # Skip if not a directory
    if [ ! -d "$repo_dir" ]; then
        continue
    fi

    repo_name=$(basename "$repo_dir")
    ((total_repos++))

    echo "Processing: $repo_name"

    # Navigate into the repo directory
    cd "$repo_dir" || {
        echo "  Failed to enter directory"
        ((failed_pushes++))
        failed_repos+=("$repo_name - Failed to enter directory")
        continue
    }

    # Initialize git repository
    if ! git init -b "$DEFAULT_BRANCH" > /dev/null 2>&1; then
        echo "  Failed to initialize git"
        ((failed_pushes++))
        failed_repos+=("$repo_name - Git init failed")
        cd - > /dev/null
        continue
    fi

    # Add all files
    if ! git add . > /dev/null 2>&1; then
        echo "  Failed to add files"
        ((failed_pushes++))
        failed_repos+=("$repo_name - Git add failed")
        cd - > /dev/null
        continue
    fi

    # Create initial commit
    if ! git commit -m "Initial commit - Migrated from GitLab" > /dev/null 2>&1; then
        echo "  Failed to create commit"
        ((failed_pushes++))
        failed_repos+=("$repo_name - Git commit failed")
        cd - > /dev/null
        continue
    fi

    # Construct the GitHub repo URL with authentication
    github_url="https://oauth2:${GITHUB_TOKEN}@${GITHUB_DOMAIN}/${GITHUB_ORG}/${repo_name}.git"

    # Add remote
    if ! git remote add origin "$github_url" > /dev/null 2>&1; then
        echo "  Failed to add remote"
        ((failed_pushes++))
        failed_repos+=("$repo_name - Add remote failed")
        cd - > /dev/null
        continue
    fi

    # Push to GitHub (filter output to hide token)
    if git push -u origin "$DEFAULT_BRANCH" 2>&1 | grep -v "oauth2" > /dev/null 2>&1; then
        echo "  Successfully pushed"
        ((successful_pushes++))
    else
        echo "  Failed to push"
        ((failed_pushes++))
        failed_repos+=("$repo_name - Push failed")
    fi

    # Return to base directory
    cd - > /dev/null
    echo ""
done

# Print summary
echo "================================"
echo "Summary"
echo "================================"
echo "Total repositories: $total_repos"
echo "Successful pushes: $successful_pushes"
echo "Failed pushes: $failed_pushes"

# Show failed repos if any
if [[ $failed_pushes -gt 0 ]]; then
    echo ""
    echo "Failed Repositories:"
    for failed_repo in "${failed_repos[@]}"; do
        echo "  $failed_repo"
    done
fi

echo ""
echo "Done"
