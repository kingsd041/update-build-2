#!/bin/bash

export ROOT_DIR="${PWD}"
export TOKEN=${CI_TOKEN}
export token=xiaoluhong:${TOKEN}
export registry=registry.cn-hangzhou.aliyuncs.com

docker login ${registry} -u${ALIYUN_ACC} -p${ALIYUN_PW}

export RANCHER_VERSION=$( curl -s https://api.github.com/repos/rancher/rancher/git/refs/tags | jq -r .[].ref | awk -F/ '{print $3}' | grep v | awk -Fv '{print $2}' | grep -v [a-z] | sort -u -t "." -k1nr,1 -k2nr,2 -k3nr,3 | grep -v ^0. | grep -v ^1. )
export CNRANCHER_VERSION=$( curl -u $token -s https://api.github.com/repos/cnrancher/pandaria/git/refs/tags | jq -r .[].ref | awk -F/ '{print $3}' | grep -v 'rc' | grep -vE 'v2.2.1-|v2.2.2-|v2.2.3-|v2.2.4-')

# rancher 镜像
for RANCHER in $( echo "${RANCHER_VERSION}" );
do
    if [[ -f "rancher-images-v${RANCHER}.txt" ]] && [[ `cat "rancher-images-v${RANCHER}.txt" | wc -l` > 10 ]]; then
        echo "已存在 rancher-images-v${RANCHER}.txt"
        cat rancher-images-v${RANCHER}.txt >> rancher-images-all.txt
    else
        curl -LSs https://github.com/rancher/rancher/releases/download/v${RANCHER}/rancher-images.txt -o rancher-images-v${RANCHER}.txt
        cat rancher-images-v${RANCHER}.txt >> rancher-images-all.txt
    fi
done

# cnrancher 镜像
for CNRANCHER in $( echo "${CNRANCHER_VERSION}" );
do
    if [[ -f "rancher-images-cn-${CNRANCHER}.txt" ]] && [[ `cat "rancher-images-cn-${CNRANCHER}.txt" | wc -l` > 10 ]]; then
        echo "已存在 rancher-images-cn-${CNRANCHER}.txt"
        cat rancher-images-cn-${CNRANCHER}.txt >> rancher-images-all.txt
    else
        asset_id=$( curl -H "Authorization: token ${TOKEN}" -H "Accept: application/vnd.github.v3.raw" -s https://api.github.com/repos/cnrancher/pandaria/releases/tags/${CNRANCHER} | jq ".assets[] | select(.name == \"rancher-images.txt\").id" )
        curl -J -sL -H "Authorization: token $TOKEN" -H "Accept: application/octet-stream" https://api.github.com/repos/cnrancher/pandaria/releases/assets/$asset_id -o rancher-images-cn-${CNRANCHER}.txt

        cat rancher-images-cn-${CNRANCHER}.txt >> rancher-images-all.txt
    fi
done

# rke 镜像
export rke_version=$( curl -u $token -s https://api.github.com/repos/rancher/rke/git/refs/tags | jq -r .[].ref | awk -F/ '{print $3}' | grep v | awk -Fv '{print $2}' | grep -v [a-z] | awk -F"." '{arr[$1"."$2]=$3}END{for(var in arr){if(arr[var]==""){print var}else{print var"."arr[var]}}}' | sort -u -t "." -k1nr,1 -k2nr,2 -k3nr,3 )

for ver in $( echo "${rke_version}" );
do
        curl -LSs https://docs.rancher.cn/download/rke/v${ver}-rke_linux-amd64 -o ./rke${ver}
        chmod +x ./rke${ver}
        ./rke${ver} config --system-images --all | grep -v 'time=' >> rancher-images-all.txt
done

# k3s 镜像
export K3S_VERSION=$( curl -u $token -s https://api.github.com/repos/rancher/k3s/git/refs/tags | jq -r .[].ref | awk -F/ '{print $3}' | grep v | awk -Fv '{print $2}' | grep -v -E "rc|alpha" | sort -u -t "." -k1nr,1 -k2nr,2 -k3nr,3 | grep -v ^0. | grep -v -E '^1.0|^1.10|^1.12|^1.13|^1.14|^1.15|^1.16' )

for K3S in $( echo "${K3S_VERSION}" );
do
    if [[ -f "k3s-images-v${K3S}.txt" ]] && [[ `cat "k3s-images-v${K3S}.txt" | wc -l` > 3 ]]; then
        echo "已存在 k3s-images-v${K3S}.txt"
        cat k3s-images-v${K3S}.txt >> k3s-images-all.txt
    else
        curl -LSs https://github.com/rancher/k3s/releases/download/v${K3S}/k3s-images.txt -o k3s-images-v${K3S}.txt
        cat k3s-images-v${K3S}.txt >> rancher-images-all.txt
    fi
done

# 排序去重
sort -u rancher-images-all.txt -o rancher-images-all.txt
touch rancher-images-done.txt

export images=$( cat rancher-images-all.txt | grep -vE 'Found|Not' )

# 定义全局项目，如果想把镜像全部同步到一个仓库，则指定一个全局项目名称；
export global_namespace=rancher   # rancher
export NS='
rancher
cnrancher
'

docker_push() {
    for imgs in $( echo "${images}" ); do

        if cat rancher-images-done.txt | grep -w ${imgs} > /dev/null ; then
            echo "镜像${imgs}已经同步"
        else
            docker pull ${imgs}

            if [[ -n "$global_namespace" ]]; then

                n=$(echo "${imgs}" | awk -F"/" '{print NF-1}')

                # 如果镜像名中没有/，那么此镜像一定是library仓库的镜像；
                if [ ${n} -eq 0 ]; then
                    export img_tag=${imgs}
                    #重命名镜像
                    docker tag ${imgs} ${registry}/${global_namespace}/${img_tag}

                    #上传镜像
                    docker push ${registry}/${global_namespace}/${img_tag}

                    #删除旧镜像
                    docker rmi ${imgs} ${registry}/${global_namespace}/${img_tag} -f

                # 如果镜像名中有一个/，那么/左侧为项目名，右侧为镜像名和tag
                elif [ ${n} -eq 1 ]; then
                    export img_tag=$(echo "${imgs}" | awk -F"/" '{print $2}')
                    export namespace=$(echo "${imgs}" | awk -F"/" '{print $1}')

                    if echo "$NS" | grep -w ${namespace} > /dev/null; then
                        #重命名镜像
                        docker tag ${imgs} ${registry}/${namespace}/${img_tag}

                        #上传镜像
                        docker push ${registry}/${namespace}/${img_tag}

                        #删除旧镜像
                        docker rmi ${imgs} ${registry}/${namespace}/${img_tag} -f
                    else
                        #重命名镜像
                        docker tag ${imgs} ${registry}/${global_namespace}/${img_tag}

                        #上传镜像
                        docker push ${registry}/${global_namespace}/${img_tag}

                        #删除旧镜像
                        docker rmi ${imgs} ${registry}/${global_namespace}/${img_tag} -f
                    fi

                # 如果镜像名中有两个/，
                elif [ ${n} -eq 2 ]; then
                    export img_tag=$(echo "${imgs}" | awk -F"/" '{print $3}')
                    export namespace=$(echo "${imgs}" | awk -F"/" '{print $2}')

                    if echo "$NS" | grep -w ${namespace} > /dev/null; then
                        #重命名镜像
                        docker tag ${imgs} ${registry}/${namespace}/${img_tag}

                        #上传镜像
                        docker push ${registry}/${namespace}/${img_tag}

                        #删除旧镜像
                        docker rmi ${imgs} ${registry}/${namespace}/${img_tag} -f
                    else
                        #重命名镜像
                        docker tag ${imgs} ${registry}/${global_namespace}/${img_tag}

                        #上传镜像
                        docker push ${registry}/${global_namespace}/${img_tag}

                        #删除旧镜像
                        docker rmi ${imgs} ${registry}/${global_namespace}/${img_tag} -f
                    fi
                else
                    #标准镜像为四层结构，即：仓库地址/项目名/镜像名:tag,如不符合此标准，即为非有效镜像。
                    echo "No available images"
                fi

                echo "${imgs}" >> rancher-images-done.txt
            else

                export n=$(echo "${imgs}" | awk -F"/" '{print NF-1}')

                # 如果镜像名中没有/，那么此镜像一定是library仓库的镜像；
                if [ ${n} -eq 0 ]; then
                    export img_tag=${imgs}
                    export namespace=library
                    #重命名镜像
                    docker tag ${imgs} ${registry}/${namespace}/${img_tag}

                    #上传镜像
                    docker push ${registry}/${namespace}/${img_tag}

                    #删除旧镜像
                    docker rmi ${imgs} ${registry}/${namespace}/${img_tag} -f

                # 如果镜像名中有一个/，那么/左侧为项目名，右侧为镜像名和tag
                elif [ ${n} -eq 1 ]; then
                    export img_tag=$(echo "${imgs}" | awk -F"/" '{print $2}')
                    export namespace=$(echo "${imgs}" | awk -F"/" '{print $1}')

                    #重命名镜像
                    docker tag ${imgs} ${registry}/${namespace}/${img_tag}

                    #上传镜像
                    docker push ${registry}/${namespace}/${img_tag}

                    #删除旧镜像
                    docker rmi ${imgs} ${registry}/${namespace}/${img_tag} -f

                # 如果镜像名中有两个/，
                elif [ ${n} -eq 2 ]; then
                    export img_tag=$(echo "${imgs}" | awk -F"/" '{print $3}')
                    export namespace=$(echo "${imgs}" | awk -F"/" '{print $2}')

                    #重命名镜像
                    docker tag ${imgs} ${registry}/${namespace}/${img_tag}

                    #上传镜像
                    docker push ${registry}/${namespace}/${img_tag}

                    #删除旧镜像
                    docker rmi ${imgs} ${registry}/${namespace}/${img_tag} -f
                else
                    #标准镜像为四层结构，即：仓库地址/项目名/镜像名:tag,如不符合此标准，即为非有效镜像。
                    echo "No available images"
                fi

                echo "${imgs}" >> rancher-images-done.txt

            fi
        fi
    done
}

docker_push