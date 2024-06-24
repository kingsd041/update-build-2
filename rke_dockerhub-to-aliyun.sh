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

# rke 镜像
export rke_version=$( curl -L -u ${token} -s https://api.github.com/repos/rancher/rke/git/refs/tags | jq -r .[].ref | awk -F/ '{print $3}' | grep v | awk -Fv '{print $2}' | grep -v [a-z] |grep -v -E '^0.|^1.0|^1.1|^1.2|^1.3' | awk -v num=3 -F"." 'BEGIN{i=1}{if(tmp==$1"."$2){i=i+1}else{tmp=$1"."$2;i=1};arr[$0]=i;arrMax[$1"."$2]=i}END{for(var in arr){split(var,arrTmp,".");if(arr[var]>=(arrMax[arrTmp[1]"."arrTmp[2]]-num)){print var}}}'|sort -r )

for ver in $( echo "${rke_version}" );
do
        curl -LSs https://github.com/rancher/rke/releases/download/v${ver}/rke_linux-amd64 -o ./rke${ver}
        chmod +x ./rke${ver}
        ls -all -h
        ./rke${ver} config --system-images --all | grep -v 'time=' >> $IMAGE_LIST
done

# 排序去重
sort -u $IMAGE_LIST -o $IMAGE_LIST

# 去掉 dockerhub 中不存在的镜像

sed -i '/noiro\/opflex-server:5.2.7.1.81c2369/d' $IMAGE_LIST
sed -i '/noiro\/gbp-server:5.2.7.1.81c2369/d' $IMAGE_LIST

echo ''
echo ''

echo 'List all images'
cat $IMAGE_LIST

echo ''
echo ''

echo 'Download all images'
export images=$( cat $IMAGE_LIST | grep -vE 'Found|Not' )

# 定义全局项目，如果想把镜像全部同步到一个仓库，则指定一个全局项目名称；
#export global_namespace=rancher   # rancher
#export NS='
#rancher
#cnrancher
#'

# 生成 hangar 同步的执行脚本
cat >sync-rke-to-aliyun.sh <<EOL
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

docker run --rm -v $(pwd):/hangar --network=host cnrancher/hangar:latest bash sync-rke-to-aliyun.sh 