#!/bin/bash

GITHUB_API_TOKEN=${GITHUB_API_TOKEN}
GITHUB_API_URL=https://api.github.com
REPO_NAME=cnrancher/website
REPO_BRANCHER=file-download
FILE_NAME=update.txt

FILE_SHA=$( curl -LSs --location --request GET -H "Authorization: Bearer ${GITHUB_API_TOKEN}" "${GITHUB_API_URL}/repos/${REPO_NAME}/contents/${FILE_NAME}?ref=${REPO_BRANCHER}" | jq -r .sha )
FILE_CONTENT=$( echo "update $(date +%Y-%m-%d:%H:%M:%S)" | base64 )

create_cluster_data()
{
    cat <<EOF
{
    "branch": "${REPO_BRANCHER}",
    "message": "update $(date +%Y-%m-%d:%H:%M:%S)",
    "committer": {
        "name": "xiaoluhong",
        "email": "xiaoluhong@rancher.com"
    },
    "content": "${FILE_CONTENT}",
    "sha": "${FILE_SHA}"
}
EOF
}

curl --location --request PUT \
-H "Authorization: Bearer ${GITHUB_API_TOKEN}" \
-d "$(create_cluster_data)" \
"${GITHUB_API_URL}/repos/${REPO_NAME}/contents/${FILE_NAME}"