#!/bin/bash

# Script to push local repos to GitHub Enterprise

set -e

# ===== CONFIGURATION - UPDATE THESE VALUES =====
SOURCE_DIR="github_ready"
GITHUB_ORG="primecorpbc"
GITHUB_TOKEN="YOUR_GITHUB_TOKEN"
GITHUB_DOMAIN="github.primecorpbc.ca"
# ===============================================

echo "================================"
echo "Push to GitHub"
echo "================================"
echo ""

if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory '$SOURCE_DIR' not found"
    exit 1
fi

echo "Source: $SOURCE_DIR"
echo "GitHub domain: $GITHUB_DOMAIN"
echo "Organization: $GITHUB_ORG"
echo ""

# Count repositories
repo_count=$(find "$SOURCE_DIR" -mindepth 2 -maxdepth 2 -type d | wc -l)
echo "Found $repo_count repositories to push"
echo ""

read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborting."
    exit 0
fi

echo ""

success_count=0
error_count=0
skipped_count=0

# Save starting directory
STARTING_DIR=$(pwd)

# Process each organization directory
for org_dir in "$SOURCE_DIR"/*; do
    if [ ! -d "$org_dir" ]; then
        continue
    fi
    
    local_org=$(basename "$org_dir")
    
    if [ "$local_org" = "migration_mapping.txt" ]; then
        continue
    fi
    
    # Process each repository
    for repo_dir in "$org_dir"/*; do
        if [ ! -d "$repo_dir" ]; then
            continue
        fi
        
        repo_name=$(basename "$repo_dir")
        full_repo_name="$GITHUB_ORG/$repo_name"
        
        echo "Pushing: $repo_name"
        
        cd "$repo_dir"
        
        # Verify .git directory exists
        if [ ! -d .git ]; then
            echo "  No .git directory, skipping"
            ((skipped_count++))
            cd "$STARTING_DIR"
            continue
        fi
        
        # Update remote to use HTTPS with token
        remote_url="https://$GITHUB_TOKEN@$GITHUB_DOMAIN/$full_repo_name.git"
        
        if git remote get-url origin &> /dev/null; then
            git remote set-url origin "$remote_url"
        else
            git remote add origin "$remote_url"
        fi
        
        # Push all branches and tags
        if git push --all origin 2>&1 && git push --tags origin 2>&1; then
            echo "  Success"
            ((success_count++))
        else
            echo "  Failed"
            ((error_count++))
        fi
        
        cd "$STARTING_DIR"
    done
done

echo ""
echo "================================"
echo "Complete"
echo "================================"
echo ""
echo "Success: $success_count"
echo "Errors: $error_count"
echo "Skipped: $skipped_count"
echo ""
