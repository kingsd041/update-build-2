#!/bin/bash

sudo apt-get install jq -y

sudo bash -c "echo 'nameserver 223.5.5.5' > /etc/resolv.conf"
cat /etc/resolv.conf

export ROOT_DIR="${PWD}"
export TOKEN=${CI_TOKEN}
export token=xiaoluhong:${TOKEN}
export registry=registry.cn-hangzhou.aliyuncs.com

# k3s 镜像
export K3S_VERSION=$( curl -u ${token} -LSs https://api.github.com/repos/k3s-io/k3s/git/refs/tags | jq -r .[].ref | awk -F/ '{print $3}' | grep v | awk -Fv '{print $2}' | grep -v -E "rc|alpha|engine|lite" | grep -v -E '^0.|^1.0|^1.10|^1.12|^1.13|^1.14|^1.15|^1.16|^1.17|^1.18|^1.19' | awk -v num=3 -F"." 'BEGIN{i=1}{if(tmp==$1"."$2){i=i+1}else{tmp=$1"."$2;i=1};arr[$0]=i;arrMax[$1"."$2]=i}END{for(var in arr){split(var,arrTmp,".");if(arr[var]>=(arrMax[arrTmp[1]"."arrTmp[2]]-num)){print var}}}'|sort -r )
for K3S in $( echo "${K3S_VERSION}" );
do
    curl -u ${token} -LSs https://github.com/k3s-io/k3s/releases/download/v${K3S}/k3s-images.txt >> rancher-images-all.txt
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
export global_namespace=rancher   # rancher
export NS='
rancher
cnrancher
'

cat >sync-k3s-to-aliyun.sh <<EOL
#!/bin/bash
hangar login ${registry} --username ${ALIYUN_ACC} --password ${ALIYUN_PW}

hangar mirror \
    -f 'rancher-images-all.txt' \
    -s 'docker.io' \
    -d '${registry}' \
    --arch amd64,arm64 \
    --destination-project ${global_namespace} \
    --os linux \
    --tls-verify=false

hangar mirror validate \
    --file='rancher-images-all.txt' \
    --source='docker.io' \
    --destination='${registry}' \
    --arch=amd64,arm64 \
    --destination-project ${global_namespace} \
    --os=linux \
    --jobs=4

EOL

ls -l 

docker run --rm -v $(pwd):/hangar --network=host cnrancher/hangar:latest bash sync-k3s-to-aliyun.sh


