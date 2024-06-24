#!/bin/bash

sudo apt-get install jq -y

sudo bash -c "echo 'nameserver 223.5.5.5' > /etc/resolv.conf"
cat /etc/resolv.conf

export ROOT_DIR="${PWD}"
export TOKEN=${CI_TOKEN}
export token=xiaoluhong:${TOKEN}
export SOURCE_REGISTRY="docker.io"
export DEST_REGISTRY="registry.cn-hangzhou.aliyuncs.com"
export IMAGE_LIST="rancher-images-all.txt"
export JOBS=4
export ARCH_LIST="amd64,arm64"
export OS_LIST="linux,windows"
export RETRY_REGISTRY="docker.io"
export DEST_REGISTRY_PROJECT="rancher"

# longhorn 镜像
export longhorn_version=$(curl -L -u $token -s https://api.github.com/repos/longhorn/longhorn/git/refs/tags | \
jq -r .[].ref | \
awk -F/ '{print $3}' | \
grep v | \
awk -Fv '{print $2}' | \
grep -vE 'alpha|rc|beta' | \
awk -F"." '{
  versions[$1"."$2][$3]++
} END {
  for (v in versions) {
    sorted_versions[NR] = v
    NR++
  }
  n = asort(sorted_versions)
  latest_versions_count = 0
  for (i = n; i > 0 && latest_versions_count < 2; i--) {
    split(sorted_versions[i], parts, ".")
    major_minor = parts[1] "." parts[2]
    max_patch = 0
    for (patch in versions[major_minor]) {
      if (patch > max_patch) {
        max_patch = patch
      }
    }
    print major_minor "." max_patch
    latest_versions_count++
  }
}' | sort -r)


for ver in $( echo "${longhorn_version}" );
do
    browser_download_url_list=$( curl -LSs https://api.github.com/repos/rancher/longhorn/releases/tags/v${ver} | jq ".assets[].browser_download_url" -r | grep txt )
    for browser_download_url in ${browser_download_url_list};
    do
        curl -u $token -LSs ${browser_download_url} | grep -v 'time=' >> rancher-images-all.txt;
    done
done

# 排序去重
sort -u rancher-images-all.txt -o rancher-images-all.txt
touch rancher-images-done.txt

echo ''
echo ''

echo 'List all images'
cat rancher-images-all.txt

echo ''
echo ''

echo 'Download all images'
export images=$( cat rancher-images-all.txt | grep -vE 'Found|Not' )

# 定义全局项目，如果想把镜像全部同步到一个仓库，则指定一个全局项目名称；
#export global_namespace=rancher   # rancher
#export NS='
#rancher
#cnrancher
#'

# 生成 hangar 同步的执行脚本
cat >sync-longhorn-to-aliyun.sh <<EOL
#!/bin/bash
    # 添加调试信息
    echo "Start mirror image list: $IMAGE_LIST"
    echo "Source registry: $SOURCE_REGISTRY"
    echo "Destination registry: $DEST_REGISTRY"
    echo "Jobs: $JOBS"
    echo "Arch list: $ARCH_LIST"
    echo "OS list: $OS_LIST"
    echo "Retry registry: $RETRY_REGISTRY"

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
        --destination-project=$DEST_REGISTRY_PROJECT \
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
            --destination-project=$DEST_REGISTRY_PROJECT \
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
        --file $IMAGE_LIST \
        --arch="$ARCH_LIST" \
        --os="$OS_LIST" \
        --jobs=$JOBS \
        --destination-project=$DEST_REGISTRY_PROJECT \
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
            --destination-project=$DEST_REGISTRY_PROJECT \
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
            --destination-project=$DEST_REGISTRY_PROJECT \
            --skip-login || true
    fi

    if [[ -e "mirror-failed.txt" ]]; then
        echo "There are still some images failed to validate after retry:"
        cat mirror-failed.txt
        exit 1
    fi
EOL

docker run --rm -v $(pwd):/hangar --network=host cnrancher/hangar:latest bash sync-longhorn-to-aliyun.sh 