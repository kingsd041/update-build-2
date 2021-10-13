#!/bin/bash

sudo apt-get install jq -y

sudo bash -c "echo 'nameserver 223.5.5.5' > /etc/resolv.conf"
cat /etc/resolv.conf

export GITHUB_API_TOKEN=${CI_TOKEN}
export GITHUB_API_URL=https://api.github.com
export REPO_NAME=xiaoluhong/k3s-sync
export REPO_BRANCHER=master
export FILE_NAME=update.txt

export FILE_SHA=$( curl -LSs --location --request GET -H "Authorization: Bearer ${GITHUB_API_TOKEN}" "${GITHUB_API_URL}/repos/${REPO_NAME}/contents/${FILE_NAME}?ref=${REPO_BRANCHER}" | jq -r .sha )
export FILE_CONTENT=$( echo "update $(date +%Y-%m-%d_%H:%M:%S)" | base64 )

create_cluster_data()
{
    cat <<EOF
{
    "branch": "${REPO_BRANCHER}",
    "message": "update $(date +%Y-%m-%d_%H:%M:%S)",
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