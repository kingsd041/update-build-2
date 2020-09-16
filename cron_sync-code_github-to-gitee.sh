#!/bin/bash

apt-get install jq -y

git config --global push.default matching
git config --global pull.ff only
git config --local user.email "xiaoluhong@rancher.com"
git config --local user.name "xiaoluhong"

ROOT_DIR="${PWD}/git-code-sync/"
mkdir -p ${ROOT_DIR}
cd ${ROOT_DIR}

export REPO_LIST="rancher rke system-charts helm3-charts charts rancher-catalog community-catalog install-docker rio k3s k3os submariner kontainer-driver-metadata"

export GITHUB_REPO_URL=github.com/rancher
export GITEE_REPO_URL=gitee.com/rancher

export GITEE_ACC=${GITEE_ACC}
export GITEE_PW=${GITEE_PW}

sync_repo_github_gitee_rancher()
{
    for REPO in ${REPO_LIST};
    do
        # 目录存在
        if [[ -d ${REPO} ]]; then
            echo "存在目录 ${REPO}"

            # 判断目录是否为 git 仓库
            cd ${REPO}
            git status >> /dev/null
            GIT_STATUS=$?
            cd ${ROOT_DIR}

            # 目录是 git 仓库
            if [[ ${GIT_STATUS} == 0 ]]; then
                echo "目录 ${REPO} 是 git 仓库"
                cd ${REPO}
                echo '获取所有远端分支'
                git fetch origin
                echo '获取所有分支更新'
                git pull origin
                echo 'clone出所有远端分支'
                git branch -r --list "origin/*"  | grep -v HEAD | grep -v master | xargs -I @ git checkout -t @
                echo '获取分支'
                BRANCH_LIST=$( git branch -a | grep -v -E 'remotes|gitee|HEAD' | sed 's/*//' | sed -e 's/^[ ]*//g' | sed -e 's/[ ]*$//g' )

                for branch in $( echo "${BRANCH_LIST}" );
                do
                    git checkout ${branch}
                    git fetch
                    git pull
                    git push -f https://${GITEE_ACC}:${GITEE_PW}@${GITEE_REPO_URL}/${REPO}.git ${branch}
                done
                echo '推送所有 tag 到 gitee'
                git push -f https://${GITEE_ACC}:${GITEE_PW}@${GITEE_REPO_URL}/${REPO}.git --tags

                cd ${ROOT_DIR}

            # 目录不是 git 仓库
            else
                echo "目录 ${REPO} 不是 git 仓库"
                echo '删除当前目录'
                rm -rf ${REPO}
                echo '克隆 repo'
                git clone --depth=1 https://${GITHUB_REPO_URL}/${REPO}.git
                cd ${REPO}
                echo '获取所有远端分支'
                git fetch origin
                echo '获取所有分支更新'
                git pull origin
                echo 'clone 出所有远端分支'
                git branch -r --list "origin/*"  | grep -v HEAD | grep -v master | xargs -I @ git checkout -t @
                echo '获取分支'
                BRANCH_LIST=$( git branch -a | grep -v -E 'remotes|gitee|HEAD' | sed 's/*//' | sed -e 's/^[ ]*//g' | sed -e 's/[ ]*$//g' )

                for branch in $( echo "${BRANCH_LIST}" );
                do
                    git checkout ${branch}
                    git fetch
                    git pull
                    git push -f https://${GITEE_ACC}:${GITEE_PW}@${GITEE_REPO_URL}/${REPO}.git ${branch}
                done
                echo '推送所有 tag 到 gitee'
                git push -f https://${GITEE_ACC}:${GITEE_PW}@${GITEE_REPO_URL}/${REPO}.git --tags
                cd ${ROOT_DIR}
            fi

        # 目录不存在
        else
            echo "不存在目录 ${REPO}"
            echo '克隆 repo'
            git clone --depth=1 https://${GITHUB_REPO_URL}/${REPO}.git
            cd ${REPO}
            echo '获取所有远端分支'
            git fetch origin
            echo '获取所有分支更新'
            git pull origin
            echo 'clone出所有远端分支'
            git branch -r --list "origin/*"  | grep -v HEAD | grep -v master | xargs -I @ git checkout -t @
            echo '获取分支'
            BRANCH_LIST=$( git branch -a | grep -v -E 'remotes|gitee|HEAD' | sed 's/*//' | sed -e 's/^[ ]*//g' | sed -e 's/[ ]*$//g' )

            for branch in $( echo "${BRANCH_LIST}" );
            do
                git checkout ${branch}
                git fetch
                git pull
                git push -f https://${GITEE_ACC}:${GITEE_PW}@${GITEE_REPO_URL}/${REPO}.git ${branch}
            done
            echo '推送所有 tag 到 gitee'
            git push -f https://${GITEE_ACC}:${GITEE_PW}@${GITEE_REPO_URL}/${REPO}.git --tags
            cd ${ROOT_DIR}
        fi
    done
}

sync_repo_github_gitee_rancher