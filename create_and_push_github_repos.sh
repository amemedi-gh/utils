#!/bin/bash

# Script to push restructured GitLab repos to GitHub Enterprise
# Creates repos via API and pushes all branches/tags

set -e

# ===== CONFIGURATION - UPDATE THESE VALUES =====
SOURCE_DIR="github_ready"
GITHUB_ORG="primecorpbc"
GITHUB_TOKEN="YOUR_GITHUB_TOKEN"
GITHUB_DOMAIN="github.primecorpbc.ca"
VISIBILITY="public"  # private or public
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
echo "Visibility: $VISIBILITY"
echo ""

# Count repositories
repo_count=$(find "$SOURCE_DIR" -mindepth 2 -maxdepth 2 -type d | wc -l)
echo "Found $repo_count repositories"
echo ""

read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborting."
    exit 0
fi

echo ""

# Log file
LOG_FILE="$SOURCE_DIR/push_log_$(date +%Y%m%d_%H%M%S).txt"
echo "Push started: $(date)" > "$LOG_FILE"
echo "" >> "$LOG_FILE"

success_count=0
error_count=0
skipped_count=0

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
        
        echo "Processing: $repo_name"
        
        cd "$repo_dir"
        
        # Verify .git directory exists
        if [ ! -d .git ]; then
            echo "  No .git directory, skipping"
            echo "SKIPPED: $full_repo_name (no .git)" >> "$LOG_FILE"
            ((skipped_count++))
            cd - > /dev/null
            continue
        fi
        
        # Check if GitHub repo exists, create if not
        http_code=$(curl -s -o /dev/null -w "%{http_code}" \
            -H "Authorization: token $GITHUB_TOKEN" \
            "https://$GITHUB_DOMAIN/api/v3/repos/$full_repo_name")
        
        if [ "$http_code" = "200" ]; then
            echo "  Repo exists on GitHub"
        elif [ "$http_code" = "404" ]; then
            echo "  Creating repo..."
            
            create_response=$(curl -s -w "\n%{http_code}" \
                -X POST \
                -H "Authorization: token $GITHUB_TOKEN" \
                -H "Accept: application/vnd.github.v3+json" \
                "https://$GITHUB_DOMAIN/api/v3/orgs/$GITHUB_ORG/repos" \
                -d "{\"name\":\"$repo_name\",\"private\":$([ "$VISIBILITY" = "private" ] && echo true || echo false)}")
            
            create_http_code=$(echo "$create_response" | tail -n1)
            
            if [ "$create_http_code" = "201" ]; then
                echo "  Created successfully"
            else
                echo "  Failed to create (HTTP $create_http_code)"
                echo "ERROR: $full_repo_name (creation failed)" >> "$LOG_FILE"
                ((error_count++))
                cd - > /dev/null
                continue
            fi
        else
            echo "  API error (HTTP $http_code)"
            echo "ERROR: $full_repo_name (API error)" >> "$LOG_FILE"
            ((error_count++))
            cd - > /dev/null
            continue
        fi
        
        # Update remote to point to GitHub Enterprise
        if git remote get-url origin &> /dev/null; then
            git remote set-url origin "git@$GITHUB_DOMAIN:$full_repo_name.git"
        else
            git remote add origin "git@$GITHUB_DOMAIN:$full_repo_name.git"
        fi
        
        # Push all branches and tags
        echo "  Pushing..."
        if git push --all origin 2>> "$LOG_FILE" && git push --tags origin 2>> "$LOG_FILE"; then
            echo "  Success"
            echo "SUCCESS: $full_repo_name" >> "$LOG_FILE"
            ((success_count++))
        else
            echo "  Push failed"
            echo "ERROR: $full_repo_name (push failed)" >> "$LOG_FILE"
            ((error_count++))
        fi
        
        cd - > /dev/null
    done
done

echo ""
echo "================================"
echo "Complete"
echo "================================"
echo ""
echo "Success: $success_count"
echo "Errors:  $error_count"
echo "Skipped: $skipped_count"
echo ""
echo "Log: $LOG_FILE"
echo ""
