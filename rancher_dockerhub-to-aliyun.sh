#!/bin/bash

sudo apt-get install jq -y

sudo bash -c "echo 'nameserver 223.5.5.5' > /etc/resolv.conf"
cat /etc/resolv.conf

touch rancher-images-all.txt

export ROOT_DIR="${PWD}"
export TOKEN=${CI_TOKEN}
export token=xiaoluhong:${TOKEN}
export SOURCE_REGISTRY="docker.io"
export DEST_REGISTRY="registry.cn-hangzhou.aliyuncs.com"
export IMAGE_LIST="rancher-images-all.txt"
export JOBS=2
export ARCH_LIST="amd64,arm64"
export OS_LIST="linux,windows"
export RETRY_REGISTRY="docker.io"

# export RANCHER_VERSION=$( curl -L -s https://api.github.com/repos/rancher/rancher/git/refs/tags | jq -r .[].ref | awk -F/ '{print $3}' | grep v | awk -Fv '{print $2}' | grep -v [a-z] | grep -vE '^0.|^1.|^2.0|^2.1|^2.2|^2.3|^2.4|^2.5|^2.6'|awk -v num=3 -F"." 'BEGIN{i=1}{if(tmp==$1"."$2){i=i+1}else{tmp=$1"."$2;i=1};arr[$0]=i;arrMax[$1"."$2]=i}END{for(var in arr){split(var,arrTmp,".");if(arr[var]>=(arrMax[arrTmp[1]"."arrTmp[2]]-num)){print var}}}'|sort -r )

# 每个主版本和次版本查询最新的一个小版本
export RANCHER_VERSION=$( curl -L -s https://api.github.com/repos/rancher/rancher/git/refs/tags | jq -r .[].ref | awk -F/ '{print $3}' | grep v | awk -Fv '{print $2}' | grep -v [a-z] | grep -vE '^0.|^1.|^2.0|^2.1.[0-9]+$|^2.2|^2.3|^2.4|^2.5|^2.6' | sort -rV | awk -F. '!a[$1"."$2]++' )
# 每个主版本和次版本查询最新的两个小版本
# export RANCHER_VERSION=$( curl -L -s https://api.github.com/repos/rancher/rancher/git/refs/tags | jq -r .[].ref | awk -F/ '{print $3}' | grep v | awk -Fv '{print $2}' | grep -v [a-z] | grep -vE '^0.|^1.|^2.0|^2.1|^2.2|^2.3|^2.4|^2.5|^2.6' | sort -rV | awk -F. '{key=$1"."$2; count[key]++; if(count[key] <= 2) print $0}' )

# rancher 镜像
for RANCHER in $( echo "${RANCHER_VERSION}" );
do
    if [[ -f "rancher-images-v${RANCHER}.txt" ]] && [[ `cat "rancher-images-v${RANCHER}.txt" | wc -l` > 10 ]]; then
        echo "已存在 rancher-images-v${RANCHER}.txt"
        cat rancher-images-v${RANCHER}.txt >> rancher-images-all.txt
    else
        curl -LSs https://github.com/rancher/rancher/releases/download/v${RANCHER}/rancher-images.txt -o rancher-images-v${RANCHER}.txt
        curl -LSs https://github.com/rancher/rancher/releases/download/v${RANCHER}/rancher-windows-images.txt -o rancher-windows-images-v${RANCHER}.txt
        # cat rancher-images-v${RANCHER}.txt rancher-windows-images-v${RANCHER}.txt >> rancher-images-all.txt

        if ! grep -q "Not Found" "rancher-images-v${RANCHER}.txt"; then
            cat rancher-images-v${RANCHER}.txt >> rancher-images-all.txt
        fi

        if ! grep -q "Not Found" "rancher-windows-images-v${RANCHER}.txt"; then
            cat rancher-windows-images-v${RANCHER}.txt >> rancher-images-all.txt
        fi

    fi
done

# 去除 'Not Found'
#if cat rancher-images-all.txt 2>&1 | grep Foundrancher > /dev/null ; then
#    cat rancher-images-all.txt 2>&1 | grep Foundrancher | awk -F'Foundrancher' '{print "rancher" $2}' >> rancher-images-1.txt;
#    cat rancher-images-all.txt 2>&1 | grep -v Foundrancher >> rancher-images-all-new.txt;
#    cat rancher-images-1.txt 2>&1 >> rancher-images-all-new.txt;
#fi

# 排序去重
sort -u rancher-images-all.txt -o rancher-images-all.txt

echo 'List all images'
cat rancher-images-all.txt

echo ''
echo ''

echo 'Download all images'
export images=$( cat rancher-images-all.txt | sort +0 -1 +1n -2 -r | grep -vE 'Found|Not' )

# 定义全局项目，如果想把镜像全部同步到一个仓库，则指定一个全局项目名称；
#export global_namespace=rancher   # rancher
#export NS='
#rancher
#cnrancher
#'

# 生成 hangar 同步的执行脚本
cat >sync-rancher-to-aliyun.sh <<EOL
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
        --timeout=120m \
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
        --file $IMAGE_LIST \
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

docker run --rm -v $(pwd):/hangar --network=host cnrancher/hangar:latest bash sync-rancher-to-aliyun.sh 