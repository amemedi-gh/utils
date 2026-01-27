#!/bin/bash
### Create github repos from repo directories
set -e

SOURCE_DIR="github_ready"
GITHUB_ORG="primecorpbc"
GITHUB_TOKEN="YOUR_GITHUB_TOKEN"
GITHUB_DOMAIN="github.primecorpbc.ca"
VISIBILITY="public"  # private or public
# ===============================================

if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory '$SOURCE_DIR' not found"
    exit 1
fi

echo "Source: $SOURCE_DIR"
echo "GitHub domain: $GITHUB_DOMAIN"
echo "Organization: $GITHUB_ORG"
echo "Visibility: $VISIBILITY"
echo ""

# Count repos
repo_count=$(find "$SOURCE_DIR" -mindepth 2 -maxdepth 2 -type d | wc -l)
echo "Found $repo_count repositories to create"
echo ""

read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborting."
    exit 0
fi

echo ""

# Log file
LOG_FILE="$SOURCE_DIR/create_repos_log_$(date +%Y%m%d_%H%M%S).txt"
echo "Repo creation started: $(date)" > "$LOG_FILE"
echo "" >> "$LOG_FILE"

created_count=0
exists_count=0
error_count=0

# Process each organization directory
for org_dir in "$SOURCE_DIR"/*; do
    if [ ! -d "$org_dir" ]; then
        continue
    fi
    
    local_org=$(basename "$org_dir")
    
    if [ "$local_org" = "migration_mapping.txt" ]; then
        continue
    fi
    
    # Process each repo
    for repo_dir in "$org_dir"/*; do
        if [ ! -d "$repo_dir" ]; then
            continue
        fi
        
        repo_name=$(basename "$repo_dir")
        full_repo_name="$GITHUB_ORG/$repo_name"
        
        echo "Checking: $repo_name"
        
        # Check if GitHub repo exists
        http_code=$(curl -s -o /dev/null -w "%{http_code}" \
            -H "Authorization: token $GITHUB_TOKEN" \
            "https://$GITHUB_DOMAIN/api/v3/repos/$full_repo_name")
        
        if [ "$http_code" = "200" ]; then
            echo "  Already exists"
            echo "EXISTS: $full_repo_name" >> "$LOG_FILE"
            ((exists_count++))
        elif [ "$http_code" = "404" ]; then
            echo "  Creating..."
            
            create_response=$(curl -s -w "\n%{http_code}" \
                -X POST \
                -H "Authorization: token $GITHUB_TOKEN" \
                -H "Accept: application/vnd.github.v3+json" \
                "https://$GITHUB_DOMAIN/api/v3/orgs/$GITHUB_ORG/repos" \
                -d "{\"name\":\"$repo_name\",\"private\":$([ "$VISIBILITY" = "private" ] && echo true || echo false)}")
            
            create_http_code=$(echo "$create_response" | tail -n1)
            
            if [ "$create_http_code" = "201" ]; then
                echo "  Created successfully"
                echo "CREATED: $full_repo_name" >> "$LOG_FILE"
                ((created_count++))
            else
                echo "  Failed (HTTP $create_http_code)"
                echo "ERROR: $full_repo_name (HTTP $create_http_code)" >> "$LOG_FILE"
                echo "$create_response" >> "$LOG_FILE"
                ((error_count++))
            fi
        else
            echo "  API error (HTTP $http_code)"
            echo "ERROR: $full_repo_name (HTTP $http_code)" >> "$LOG_FILE"
            ((error_count++))
        fi
    done
done

echo "================================"
echo "Complete"
echo "================================"
echo "Created: $created_count"
echo "Already existed: $exists_count"
echo "Errors: $error_count"
echo "Log: $LOG_FILE"
