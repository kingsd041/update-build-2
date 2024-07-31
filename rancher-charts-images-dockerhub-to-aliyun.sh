
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

export GENERATED_IMAGE_LIST_27="rancher-2.7-charts-images.txt"
export GENERATED_IMAGE_LIST_28="rancher-2.8-charts-images.txt"
export GENERATED_IMAGE_LIST_ALL="rancher-charts-images.txt"

git clone --depth 1 --branch release-v2.7 https://github.com/rancher/charts rancher-charts-v2.7
git clone --depth 1 --branch release-v2.8 https://github.com/rancher/charts rancher-charts-v2.8

# Generate image list from rancher/charts git repo in Drone CI
echo "Generate image list from rancher/charts repo, branch release-v2.7 and release-v2.8"

cat >generate-rancher-charts-list.sh <<EOL
#/bin/bash
hangar generate-list \
    --rancher="v2.7.99" \
    --chart="rancher-charts-v2.7" \
    --output="$GENERATED_IMAGE_LIST_27"

echo "Generate image list from rancher/charts repo, branch release-v2.8"
hangar generate-list \
    --rancher="v2.8.99" \
    --chart="rancher-charts-v2.8" \
    --output="$GENERATED_IMAGE_LIST_28"
EOL

docker run --rm -v $(pwd):/hangar --network=host cnrancher/hangar:latest bash generate-rancher-charts-list.sh

# FYI: https://github.com/rancher/rancher/pull/41951
# Remove images in 'rancher-charts-daily-ignore-images.txt' from generated image list
while IFS= read -r line
do
    grep -v "$line" "$GENERATED_IMAGE_LIST_27" > tmp.txt
    mv tmp.txt ${GENERATED_IMAGE_LIST_27}

    grep -v "$line" "$GENERATED_IMAGE_LIST_28" > tmp.txt
    mv tmp.txt ${GENERATED_IMAGE_LIST_28}
done < "rancher-charts-daily-ignore-images.txt"

# 添加换行符，解决两个文件收尾拼接位一行的问题
# sed -i -e '$a\' $GENERATED_IMAGE_LIST_27
# sed -i -e '$a\' $GENERATED_IMAGE_LIST_28

# 合并
cat $GENERATED_IMAGE_LIST_27 $GENERATED_IMAGE_LIST_28 > $GENERATED_IMAGE_LIST_ALL

# 排序去重
sort -u $GENERATED_IMAGE_LIST_ALL -o $GENERATED_IMAGE_LIST_ALL

echo ''
echo ''

echo 'List all images'
cat -n $GENERATED_IMAGE_LIST_ALL

echo ''
echo ''


# 生成 hangar 同步的执行脚本
cat >sync-rancher-chart-to-aliyun.sh <<EOL
#!/bin/bash
    # 添加调试信息
    echo "Start mirror image list: $GENERATED_IMAGE_LIST_ALL"
    echo "Source registry: $SOURCE_REGISTRY"
    echo "Destination registry: $DEST_REGISTRY"
    echo "Jobs: $JOBS"
    echo "Arch list: $ARCH_LIST"
    echo "OS list: $OS_LIST"
    echo "Retry registry: $RETRY_REGISTRY"

    echo "Start mirror image list: $GENERATED_IMAGE_LIST_ALL"

    hangar login ${DEST_REGISTRY} --username ${ALIYUN_ACC} --password ${ALIYUN_PW}

    hangar mirror \
        --source="$SOURCE_REGISTRY" \
        --destination="$DEST_REGISTRY" \
        --file="$GENERATED_IMAGE_LIST_ALL" \
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
        --file $GENERATED_IMAGE_LIST_ALL \
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

docker run --rm -v $(pwd):/hangar --network=host cnrancher/hangar:latest bash sync-rancher-chart-to-aliyun.sh
