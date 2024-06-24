#!/bin/bash

# sudo bash -c "echo 'nameserver 223.5.5.5' > /etc/resolv.conf"
# cat /etc/resolv.conf

# 清理 action 镜像磁盘空间
# https://github.com/actions/runner-images/issues/2840
sudo rm -rf /usr/share/dotnet
sudo rm -rf /opt/ghc
sudo rm -rf "/usr/local/share/boost"
sudo rm -rf "$AGENT_TOOLSDIRECTORY"

sudo apt-get install jq -y

export ROOT_DIR="${PWD}"
export TOKEN=${CI_TOKEN}
export token=xiaoluhong:${TOKEN}
export SOURCE_REGISTRY="docker.io"
export DEST_REGISTRY="registry.cn-hangzhou.aliyuncs.com"
export JOBS=4
export ARCH_LIST="amd64,arm64"
export OS_LIST="linux,windows"
export RETRY_REGISTRY="docker.io"

# v2.8-global-kdm-data.json: Global KDM data.json
export CATTLE_KDM_BRANCH="release-v2.8"
export RANCHER_MAJOR_MINOR_VERSION="2.8"

GLOBAL_KDM_FILENAME="${RANCHER_MAJOR_MINOR_VERSION}-global-kdm-data.json"


# v2.8-global-versions.txt: Global KDM 版本列表
GENERATED_GLOBAL_VERSION_LIST="$RANCHER_MAJOR_MINOR_VERSION-global-versions.txt"

# GLOBAL KDM all images
GENERATED_GLOBAL_IMAGE_LIST="$RANCHER_MAJOR_MINOR_VERSION-global-images.txt"

echo "Download $RANCHER_MAJOR_MINOR_VERSION GC KDM data.json"
wget --tries=3 https://releases.rancher.com/kontainer-driver-metadata/${CATTLE_KDM_BRANCH}/data.json -O $GLOBAL_KDM_FILENAME

# Ensure the download file is not empty.
if [ ! -s $GLOBAL_KDM_FILENAME ]; then
    ls -alh *.json
    echo "Failed to download KDM data.json, file is empty!"
    exit 1
fi

# Generate KDM image list from drone CI since the EKSCI cannot
# download assets from GitHub Release.
echo "Generate image list from Global RPM KDM data.json"

cat >generate-rancher-list.sh <<EOL
#!/bin/bash
hangar generate-list \
    --rancher="$RANCHER_MAJOR_MINOR_VERSION.99" \
    --kdm="$GLOBAL_KDM_FILENAME" \
    --output="$GENERATED_GLOBAL_IMAGE_LIST" \
    --output-versions="$GENERATED_GLOBAL_VERSION_LIST" \
    --auto-yes
echo "Generated KDM versions of Global $RANCHER_MAJOR_MINOR_VERSION.99 :"
cat $GENERATED_GLOBAL_VERSION_LIST
EOL

docker run --rm -v $(pwd):/hangar --network=host cnrancher/hangar:latest bash generate-rancher-list.sh


# 排序去重
sort -u $GENERATED_GLOBAL_VERSION_LIST -o $GENERATED_GLOBAL_VERSION_LIST

echo ''
echo ''

echo 'List all images'
cat $GENERATED_GLOBAL_VERSION_LIST

echo ''
echo ''

echo 'Download all images'
export images=$( cat $GENERATED_GLOBAL_VERSION_LIST | grep -vE 'Found|Not' )

# 定义全局项目，如果想把镜像全部同步到一个仓库，则指定一个全局项目名称；
#export global_namespace=rancher   # rancher
#export NS='
#rancher
#cnrancher
#'

# 生成 hangar 同步的执行脚本
cat >sync-rancher28-to-aliyun.sh <<EOL
#!/bin/bash
    # 添加调试信息
    echo "Start mirror image list: $GENERATED_GLOBAL_IMAGE_LIST"
    echo "Source registry: $SOURCE_REGISTRY"
    echo "Destination registry: $DEST_REGISTRY"
    echo "Jobs: $JOBS"
    echo "Arch list: $ARCH_LIST"
    echo "OS list: $OS_LIST"
    echo "Retry registry: $RETRY_REGISTRY"

    echo "Start mirror image list: $GENERATED_GLOBAL_IMAGE_LIST"

    hangar login ${DEST_REGISTRY} --username ${ALIYUN_ACC} --password ${ALIYUN_PW}

    hangar mirror \
        --source="$SOURCE_REGISTRY" \
        --destination="$DEST_REGISTRY" \
        --file="$GENERATED_GLOBAL_IMAGE_LIST" \
        --jobs="$JOBS" \
        --arch="$ARCH_LIST" \
        --os="$OS_LIST" \
        --timeout=60m \
        --skip-login || true

    if [[ -e "mirror-failed.txt" ]]; then
        echo "There are some images failed to mirror:"
        cat mirror-failed.txt
        echo "-------------------------------"
        mv mirror-failed.txt mirror-failed-1.txt
        hangar mirror \
            --source="$RETRY_REGISTRY" \
            --destination="$DEST_REGISTRY" \
            --file="./mirror-failed-1.txt" \
            --arch="$ARCH_LIST" \
            --os="$OS_LIST" \
            --jobs=$JOBS \
            --skip-login || true
    fi

    if [[ -e "mirror-failed.txt" ]]; then
        echo "There are still some images failed to mirror after retry:"
        cat mirror-failed.txt
        exit 1
    fi

    echo "-------------------------------"
    hangar mirror validate \
        --source="$SOURCE_REGISTRY" \
        --destination="$DEST_REGISTRY" \
        --file $GENERATED_GLOBAL_IMAGE_LIST \
        --arch="$ARCH_LIST" \
        --os="$OS_LIST" \
        --jobs=$JOBS \
        --skip-login || true

    if [[ -e "mirror-failed.txt" ]]; then
        echo "There are some images failed to validate:"
        cat mirror-failed.txt
        echo "-------------------------------"
        mv mirror-failed.txt mirror-failed-1.txt
        echo "Re-mirror the validate failed images:"
        hangar mirror \
            --source="$RETRY_REGISTRY" \
            --destination="$DEST_REGISTRY" \
            --file="mirror-failed-1.txt" \
            --arch="$ARCH_LIST" \
            --os="$OS_LIST" \
            --jobs=$JOBS \
            --skip-login || true
            
        echo "-------------------------------"
        echo "Re-validate the validate failed images:"
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
        echo "There are still some images failed to validate after retry:"
        cat mirror-failed.txt
        exit 1
    fi
EOL

docker run --rm -v $(pwd):/hangar --network=host cnrancher/hangar:latest bash sync-rancher28-to-aliyun.sh 
