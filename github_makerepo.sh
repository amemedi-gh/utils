#!/bin/bash

REPO_NAME="CHANGEME"
ORG_NAME="CHANGEME"
GITHUB_TOKEN="CHANGEME"
GITHUB_DOMAIN="github.CHANGE.ME"



curl -X POST \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.v3+json" \
  https://${GITHUB_DOMAIN}/api/v3/orgs/${ORG_NAME}/repos \
  -d "{\"name\":\"${REPO_NAME}\",\"private\":true}"



###push mirror reference
#cd to repo dir
#git remote remove origin
#git remote add origin "https://your-github-enterprise-server/${ORG_NAME}/${REPO_NAME}.git"
#git push --mirror
