#!/bin/bash

sudo apt-get install jq -y

sudo bash -c "echo 'nameserver 223.5.5.5' > /etc/resolv.conf"
cat /etc/resolv.conf

export ROOT_DIR="${PWD}"
export TOKEN=${CI_TOKEN}
export token="xiaoluhong:${TOKEN}"

export SOURCE_REGISTRY="docker.io"
export DEST_REGISTRY="registry.cn-hangzhou.aliyuncs.com"
export IMAGE_LIST="k3k-images.txt"
export JOBS=4
export ARCH_LIST=""
export OS_LIST="linux"
export RETRY_REGISTRY="docker.io"


echo "======================================================"
echo " Fetching K3K tags from GitHub"
echo "======================================================"

# -------------------------------
# GitHub tag list helper
# -------------------------------
get_github_tags() {
    REPO=$1
    ORG=$2

    curl -u ${token} -LSs "https://api.github.com/repos/${ORG}/${REPO}/git/refs/tags" \
        | jq -r .[].ref \
        | awk -F/ '{print $3}' \
        | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
        | grep -v -E 'rc|alpha|beta' \
        | grep -v -E '^v0\.[0-9]+\.[0-9]+$' \
        | sort -V
}

# -------------------------------
# 获取 K3K tag
# -------------------------------
echo "Fetching K3K tags ..."
K3K_TAGS=$( get_github_tags "k3k" "rancher" )


echo ""
echo "======================================================"
echo " Generate k3k-images.txt"
echo "======================================================"

rm -f ${IMAGE_LIST}
touch ${IMAGE_LIST}

# -------------------------------
# 组装 K3K & K3K-kubelet 镜像
# -------------------------------
for TAG in ${K3K_TAGS}; do
    echo "rancher/k3k:${TAG}" | tee -a ${IMAGE_LIST}
    echo "rancher/k3k-kubelet:${TAG}" | tee -a ${IMAGE_LIST}
    echo "rancher/k3s:${TAG}" | tee -a ${IMAGE_LIST}
done

sort -u ${IMAGE_LIST} -o ${IMAGE_LIST}

echo ""
echo "======================================================"
echo " Final image list:"
echo "======================================================"
cat ${IMAGE_LIST}
echo ""


# -------------------------------
# 创建 hangar mirror 执行脚本
# -------------------------------
cat >sync-k3k-to-aliyun.sh <<EOL
#!/bin/bash

echo "Start mirror image list: $IMAGE_LIST"

hangar login ${DEST_REGISTRY} --username ${ALIYUN_ACC} --password ${ALIYUN_PW}

hangar mirror \
    --source="$SOURCE_REGISTRY" \
    --destination="$DEST_REGISTRY" \
    --file="$IMAGE_LIST" \
    --jobs="$JOBS" \
    --arch="$ARCH_LIST" \
    --os="$OS_LIST" \
    --timeout=60m \
    --skip-login || true

# retry logic
if [[ -e "mirror-failed.txt" ]]; then
    echo "Retrying failed images..."
    cat mirror-failed.txt
    mv mirror-failed.txt mirror-failed-1.txt

    hangar mirror \
        --source="$RETRY_REGISTRY" \
        --destination="$DEST_REGISTRY" \
        --file="mirror-failed-1.txt" \
        --arch="$ARCH_LIST" \
        --os="$OS_LIST" \
        --jobs=$JOBS \
        --skip-login || true
fi


# validate
if [[ -e "mirror-failed.txt" ]]; then
    echo "Validate failed images:"
    cat mirror-failed.txt
    mv mirror-failed.txt mirror-failed-1.txt

    hangar mirror validate \
        --source="$RETRY_REGISTRY" \
        --destination="$DEST_REGISTRY" \
        --file="mirror-failed-1.txt" \
        --arch="$ARCH_LIST" \
        --os="$OS_LIST" \
        --jobs=$JOBS \
        --skip-login || true
fi

if [[ -e "mirror-failed.txt" ]]; then
    echo "Still failed:"
    cat mirror-failed.txt
    exit 1
fi
EOL


chmod +x sync-k3k-to-aliyun.sh
ls -l

echo ""
echo "======================================================"
echo " Start syncing images to Aliyun"
echo "======================================================"

docker run --rm -v \$(pwd):/hangar --network=host cnrancher/hangar:latest bash sync-k3k-to-aliyun.sh
