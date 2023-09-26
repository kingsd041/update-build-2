#!/bin/bash

sudo apt-get install jq -y

sudo bash -c "echo 'nameserver 223.5.5.5' > /etc/resolv.conf"
cat /etc/resolv.conf

#ping hub.rancher.cn -w 3

touch version-list.txt
touch images-done.txt
touch rancher-images-all.txt

export ROOT_DIR="${PWD}"
export TOKEN=${CI_TOKEN}
export token=xiaoluhong:${TOKEN}
export registry=hub.rancher.cn

docker login ${registry} -u${RANCHER_HUB_ACC} -p${RANCHER_HUB_PW}
docker login -u${DOCKER_HUB_ACC} -p${DOCKER_HUB_PW}

#export RANCHER_VERSION=$( curl -u ${token} -s https://api.github.com/repos/rancher/rancher/git/refs/tags | jq -r .[].ref | awk -F/ '{print $3}' | grep v | grep -v windows | awk -Fv '{print $2}' | grep -v [a-z] | grep -vE '^0.|^1.|^2.0|^2.1|^2.2|^2.3'|awk -v num=3 -F"." 'BEGIN{i=1}{if(tmp==$1"."$2){i=i+1}else{tmp=$1"."$2;i=1};arr[$0]=i;arrMax[$1"."$2]=i}END{for(var in arr){split(var,arrTmp,".");if(arr[var]>=(arrMax[arrTmp[1]"."arrTmp[2]]-num)){print var}}}'|sort -r )
#export RANCHER_VERSION=$( curl -s https://api.github.com/repos/rancher/rancher/git/refs/tags | jq -r .[].ref | awk -F/ '{print $3}' | grep v | grep -v windows | awk -Fv '{print $2}' | grep -v [a-z] | sort -u -t "." -k1nr,1 -k2nr,2 -k3nr,3 | grep -v ^0. | grep -v ^1. )
#export CNRANCHER_VERSION=$( curl -L -u $token -s https://api.github.com/repos/cnrancher/pandaria/git/refs/tags | jq -r .[].ref | awk -F/ '{print $3}' | grep -v 'rc' | grep -vE 'v2.2.1-|v2.2.2-|v2.2.3-|v2.2.4-')
export CNRANCHER_VERSION=$( curl -L -u ${token} -s https://api.github.com/repos/cnrancher/pandaria/git/refs/tags | jq -r .[].ref | awk -F/ '{print $3}' | grep v | awk -Fv '{print $2}' | grep -v -E 'rc|2.2'|sort -r )

# # rancher 镜像
##for RANCHER in $( echo "${RANCHER_VERSION}" );
##do
##    curl -u ${token} -LSs https://github.com/rancher/rancher/releases/download/v${RANCHER}/rancher-images.txt >> rancher-images-all.txt;
##done

# cnrancher 镜像
for CNRANCHER in $( echo "${CNRANCHER_VERSION}" );
do
    asset_id_1=$( curl -H "Authorization: token ${TOKEN}" -H "Accept: application/vnd.github.v3.raw" -s https://api.github.com/repos/cnrancher/pandaria/releases/tags/v${CNRANCHER} | jq ".assets[] | select(.name == \"rancher-images.txt\").id" )
    curl -J -sL -H "Authorization: token ${TOKEN}" -H "Accept: application/octet-stream" https://api.github.com/repos/cnrancher/pandaria/releases/assets/${asset_id_1} >> rancher-images-all.txt;

    asset_id_2=$( curl -H "Authorization: token ${TOKEN}" -H "Accept: application/vnd.github.v3.raw" -s https://api.github.com/repos/cnrancher/pandaria/releases/tags/v${CNRANCHER} | jq ".assets[] | select(.name == \"pandaria-catalog-images.txt\").id" )
    curl -J -sL -H "Authorization: token ${TOKEN}" -H "Accept: application/octet-stream" https://api.github.com/repos/cnrancher/pandaria/releases/assets/${asset_id_2} >> rancher-images-all.txt;

done

# rke 镜像
#export rke_version=$( curl -s https://api.github.com/repos/rancher/rke/git/refs/tags | jq -r .[].ref | awk -F/ '{print $3}' | grep v | awk -Fv '{print $2}' | grep -v [a-z] | awk -F"." '{arr[$1"."$2]=$3}END{for(var in arr){if(arr[var]==""){print var}else{print var"."arr[var]}}}' | sort -u -t "." -k1nr,1 -k2nr,2 -k3nr,3 )
##export rke_version=$( curl -u ${token} -s https://api.github.com/repos/rancher/rke/git/refs/tags | jq -r .[].ref | awk -F/ '{print $3}' | grep v | awk -Fv '{print $2}' | grep -v [a-z] | grep -v -E '^0.' | awk -v num=3 -F"." 'BEGIN{i=1}{if(tmp==$1"."$2){i=i+1}else{tmp=$1"."$2;i=1};arr[$0]=i;arrMax[$1"."$2]=i}END{for(var in arr){split(var,arrTmp,".");if(arr[var]>=(arrMax[arrTmp[1]"."arrTmp[2]]-num)){print var}}}'|sort -r )

##for ver in $( echo "${rke_version}" );
##do
##    curl -u ${token} -LSs https://github.com/rancher/rke/releases/download/v${ver}/rke_linux-amd64 -o ./rke${ver}
##    chmod +x ./rke${ver}
##    ./rke${ver} config --system-images --all | grep -v 'time=' >> rancher-images-all.txt
##done
##
### k3s 镜像
##export K3S_VERSION=$( curl -u ${token} -s https://api.github.com/repos/k3s-io/k3s/git/refs/tags | jq -r .[].ref | awk -F/ '{print $3}' | grep v | awk -Fv '{print $2}' | grep -v -E "rc|alpha|engine|lite" | grep -v -E '^0.|^1.0|^1.10|^1.12|^1.13|^1.14|^1.15|^1.16|^1.17|^1.18|^1.19' | awk -v num=3 -F"." 'BEGIN{i=1}{if(tmp==$1"."$2){i=i+1}else{tmp=$1"."$2;i=1};arr[$0]=i;arrMax[$1"."$2]=i}END{for(var in arr){split(var,arrTmp,".");if(arr[var]>=(arrMax[arrTmp[1]"."arrTmp[2]]-num)){print var}}}'|sort -r )
##
##for K3S in $( echo "${K3S_VERSION}" );
##do
##    curl -u ${token} -LSs https://github.com/k3s-io/k3s/releases/download/v${K3S}/k3s-images.txt >> rancher-images-all.txt;
##done
##
### rke2 镜像
##export rke2_version=$( curl -u ${token} -L -s https://api.github.com/repos/rancher/rke2/git/refs/tags | jq -r .[].ref | awk -F/ '{print $3}' | grep v | awk -Fv '{print $2}' | grep -v -E 'alpha|rc|beta|^1.18|^1.19' | awk -v num=3 -F"." 'BEGIN{i=1}{if(tmp==$1"."$2){i=i+1}else{tmp=$1"."$2;i=1};arr[$0]=i;arrMax[$1"."$2]=i}END{for(var in arr){split(var,arrTmp,".");if(arr[var]>=(arrMax[arrTmp[1]"."arrTmp[2]]-num)){print var}}}'|sort -r  )
##
##for ver in $( echo "${rke2_version}" );
##do
##    browser_download_url_list=$( curl -u ${token} -LSs https://api.github.com/repos/rancher/rke2/releases/tags/v${ver} | jq ".assets[].browser_download_url" -r | grep txt | grep amd64 | grep linux )
##
##    for browser_download_url in ${browser_download_url_list};
##    do
##        curl -u ${token} -LSs ${browser_download_url} | grep -v 'time=' >> rancher-images-all.txt;
##    done
##done

cat rancher-images-all.txt | grep -vE 'documentation_url|{|}|Found|Not|AuthenticationFailed|AuthenticationErrorDetail|arm64|windows' | sed 's/Not Founddocker/docker/' | sed 's#registry.rancher.cn/##' > rancher-images-all-new.txt

# 排序去重
sort -u rancher-images-all-new.txt -o rancher-images-all-new.txt

ls -all -h

cat rancher-images-all-new.txt | sort +0 -1 +1n -2 -r

export images=$( cat rancher-images-all-new.txt | sort +0 -1 +1n -2 -r )

# 定义全局项目，如果想把镜像全部同步到一个仓库，则指定一个全局项目名称；
# export global_namespace=rancher   # rancher
export NS='
rancher
cnrancher
'

docker_push() {
    for imgs in $( echo "${images}" ); do

        export n=$(echo "${imgs}" | awk -F"/" '{print NF-1}')

        # 如果镜像名中没有 /，那么此镜像一定是 library 仓库的镜像；
        if [ ${n} -eq 0 ]; then
            export projects=library
            export repositories=$(echo "${imgs}" | awk -F':' '{print $1}')
            export tag=$(echo "${imgs}" | awk -F':' '{print $2}')

            if [[ ${tag} != '' ]]; then
                export CHECK_STATUS_CODE=$( curl -LSs -X 'GET' -H 'accept: application/json' -u "${RANCHER_HUB_ACC}:${RANCHER_HUB_PW}" "https://hub.rancher.cn/api/v2.0/projects/${projects}/repositories/${repositories}/artifacts?page=-1&page_size=-1" | jq -r '.[].tags[].name' | grep -Fx -q ${tag} && echo $? )
            else
                export CHECK_STATUS_CODE=1
            fi

        # 如果镜像名中有一个 /，那么 / 左侧为项目名，右侧为镜像名和 tag
        elif [ ${n} -eq 1 ]; then
            export projects=$(echo "${imgs}" | awk -F"/" '{print $1}')
            export repositories=$(echo "${imgs}" | awk -F"/" '{print $2}' | awk -F':' '{print $1}')
            export tag=$(echo "${imgs}" | awk -F"/" '{print $2}' | awk -F':' '{print $2}')

            if [[ ${tag} != '' ]]; then
                export CHECK_STATUS_CODE=$( curl -LSs -X 'GET' -H 'accept: application/json' -u "${RANCHER_HUB_ACC}:${RANCHER_HUB_PW}" "https://hub.rancher.cn/api/v2.0/projects/${projects}/repositories/${repositories}/artifacts?page=-1&page_size=-1" | jq -r '.[].tags[].name' | grep -Fx -q ${tag} && echo $? )
            else
                export CHECK_STATUS_CODE=1
            fi
        # 如果镜像名中有两个 /，
        elif [ ${n} -eq 2 ]; then
            export projects=$(echo "${imgs}" | awk -F"/" '{print $2}')
            export repositories=$(echo "${imgs}" | awk -F"/" '{print $3}' | awk -F':' '{print $1}')
            export tag=$(echo "${imgs}" | awk -F"/" '{print $3}' | awk -F':' '{print $2}')

            if [[ ${tag} != '' ]]; then
                export CHECK_STATUS_CODE=$( curl -LSs -X 'GET' -H 'accept: application/json' -u "${RANCHER_HUB_ACC}:${RANCHER_HUB_PW}" "https://hub.rancher.cn/api/v2.0/projects/${projects}/repositories/${repositories}/artifacts?page=-1&page_size=-1" | jq -r '.[].tags[].name' | grep -Fx -q ${tag} && echo $? )
            else
                export CHECK_STATUS_CODE=1
            fi
        # 标准镜像为四层结构，即：仓库地址/项目名/镜像名:tag，如不符合此标准，即为非有效镜像。
        else
            echo "No available images"
        fi


        echo " CHECK_STATUS_CODE = ${CHECK_STATUS_CODE} "
        if [[ ${CHECK_STATUS_CODE} == '0' ]]; then
            echo "镜像 ${registry}/${imgs} 已同步"
        else
            docker pull ${imgs} 2>&1 > /dev/null

            if [[ -n "${global_namespace}" ]]; then

                # 如果镜像名中没有/，那么此镜像一定是library仓库的镜像；
                if [ ${n} -eq 0 ]; then
                    export img_tag=${imgs}
                    #重命名镜像
                    echo "TAG IMAGES ${registry}/${global_namespace}/${img_tag}"
                    docker tag ${imgs} ${registry}/${global_namespace}/${img_tag}

                    #上传镜像
                    echo "PUSH IMAGES ${registry}/${global_namespace}/${img_tag}"
                    docker push ${registry}/${global_namespace}/${img_tag} 2>&1 > /dev/null

                    #删除旧镜像
                    echo "DELETE LOCAL IMAGES ${registry}/${global_namespace}/${img_tag}"
                    docker rmi ${imgs} ${registry}/${global_namespace}/${img_tag} -f 2>&1 > /dev/null

                # 如果镜像名中有一个/，那么/左侧为项目名，右侧为镜像名和tag
                elif [ ${n} -eq 1 ]; then
                    export img_tag=$(echo "${imgs}" | awk -F"/" '{print $2}')
                    export namespace=$(echo "${imgs}" | awk -F"/" '{print $1}')

                    if echo "$NS" | grep -w ${namespace} > /dev/null; then
                        #重命名镜像
                        echo "TAG IMAGES ${imgs} ${registry}/${namespace}/${img_tag}"
                        docker tag ${imgs} ${registry}/${namespace}/${img_tag}

                        #上传镜像
                        echo "PUSH IMAGES ${imgs} ${registry}/${namespace}/${img_tag}"
                        docker push ${registry}/${namespace}/${img_tag} 2>&1 > /dev/null

                        #删除旧镜像
                        echo "DELETE LOCAL IMAGES ${imgs} ${registry}/${namespace}/${img_tag}"
                        docker rmi ${imgs} ${registry}/${namespace}/${img_tag} -f 2>&1 > /dev/null
                    else
                        #重命名镜像
                        echo "TAG IMAGES ${imgs} ${registry}/${global_namespace}/${img_tag}"
                        docker tag ${imgs} ${registry}/${global_namespace}/${img_tag}

                        #上传镜像
                        echo "PUSH IMAGES ${imgs} ${registry}/${global_namespace}/${img_tag}"
                        docker push ${registry}/${global_namespace}/${img_tag} 2>&1 > /dev/null

                        #删除旧镜像
                        echo "DELETE LOCAL IMAGES ${imgs} ${registry}/${global_namespace}/${img_tag}"
                        docker rmi ${imgs} ${registry}/${global_namespace}/${img_tag} -f 2>&1 > /dev/null
                    fi

                # 如果镜像名中有两个/，
                elif [ ${n} -eq 2 ]; then
                    export img_tag=$(echo "${imgs}" | awk -F"/" '{print $3}')
                    export namespace=$(echo "${imgs}" | awk -F"/" '{print $2}')

                    if echo "$NS" | grep -w ${namespace} > /dev/null; then
                        #重命名镜像
                        echo "TAG IMAGES ${imgs} ${registry}/${namespace}/${img_tag}"
                        docker tag ${imgs} ${registry}/${namespace}/${img_tag}

                        #上传镜像
                        echo "PUSH IMAGES ${imgs} ${registry}/${namespace}/${img_tag}"
                        docker push ${registry}/${namespace}/${img_tag} 2>&1 > /dev/null

                        #删除旧镜像
                        echo "DELETE LOCAL IMAGES ${imgs} ${registry}/${namespace}/${img_tag}"
                        docker rmi ${imgs} ${registry}/${namespace}/${img_tag} -f 2>&1 > /dev/null

                    else
                        #重命名镜像
                        echo "TAG IMAGES ${imgs} ${registry}/${global_namespace}/${img_tag}"
                        docker tag ${imgs} ${registry}/${global_namespace}/${img_tag}

                        #上传镜像
                        echo "PUSH IMAGES ${imgs} ${registry}/${global_namespace}/${img_tag}"
                        docker push ${registry}/${global_namespace}/${img_tag} 2>&1 > /dev/null

                        #删除旧镜像
                        echo "DELETE LOCAL IMAGES ${imgs} ${registry}/${global_namespace}/${img_tag}"
                        docker rmi ${imgs} ${registry}/${global_namespace}/${img_tag} -f 2>&1 > /dev/null
                    fi
                else
                    #标准镜像为四层结构，即：仓库地址/项目名/镜像名:tag,如不符合此标准，即为非有效镜像。
                    echo "No available images"
                fi

                echo "${imgs}" >> images-done.txt
            else

                export n=$(echo "${imgs}" | awk -F"/" '{print NF-1}')

                # 如果镜像名中没有/，那么此镜像一定是 library 仓库的镜像；
                if [ ${n} -eq 0 ]; then
                    export img_tag=${imgs}
                    export namespace=library
                    #重命名镜像
                    echo "TAG IMAGES ${imgs} ${registry}/${namespace}/${img_tag}"
                    docker tag ${imgs} ${registry}/${namespace}/${img_tag}

                    #上传镜像
                    echo "PUSH IMAGES ${imgs} ${registry}/${namespace}/${img_tag}"
                    docker push ${registry}/${namespace}/${img_tag} 2>&1 > /dev/null

                    #删除旧镜像
                    echo "DELETE LOCAL IMAGES ${imgs} ${registry}/${namespace}/${img_tag}"
                    docker rmi ${imgs} ${registry}/${namespace}/${img_tag} -f 2>&1 > /dev/null

                # 如果镜像名中有一个/，那么/左侧为项目名，右侧为镜像名和tag
                elif [ ${n} -eq 1 ]; then
                    export img_tag=$(echo "${imgs}" | awk -F"/" '{print $2}')
                    export namespace=$(echo "${imgs}" | awk -F"/" '{print $1}')

                    #重命名镜像
                    echo "TAG IMAGES ${imgs} ${registry}/${namespace}/${img_tag}"
                    docker tag ${imgs} ${registry}/${namespace}/${img_tag}

                    #上传镜像
                    echo "PUSH IMAGES ${imgs} ${registry}/${namespace}/${img_tag}"
                    docker push ${registry}/${namespace}/${img_tag} 2>&1 > /dev/null

                    #删除旧镜像
                    echo "DELETE LOCAL IMAGES ${imgs} ${registry}/${namespace}/${img_tag}"
                    docker rmi ${imgs} ${registry}/${namespace}/${img_tag} -f 2>&1 > /dev/null

                # 如果镜像名中有两个/，
                elif [ ${n} -eq 2 ]; then
                    export img_tag=$(echo "${imgs}" | awk -F"/" '{print $3}')
                    export namespace=$(echo "${imgs}" | awk -F"/" '{print $2}')

                    #重命名镜像
                    echo "TAG IMAGES ${imgs} ${registry}/${namespace}/${img_tag}"
                    docker tag ${imgs} ${registry}/${namespace}/${img_tag}

                    #上传镜像
                    echo "PUSH IMAGES ${imgs} ${registry}/${namespace}/${img_tag}"
                    docker push ${registry}/${namespace}/${img_tag} 2>&1 > /dev/null

                    #删除旧镜像
                    echo "DELETE LOCAL IMAGES ${imgs} ${registry}/${namespace}/${img_tag}"
                    docker rmi ${imgs} ${registry}/${namespace}/${img_tag} -f 2>&1 > /dev/null
                else
                    #标准镜像为四层结构，即：仓库地址/项目名/镜像名:tag,如不符合此标准，即为非有效镜像。
                    echo "No available images"
                fi

                echo "${imgs}" >> images-done.txt

            fi
        fi
    done
}

docker_push
