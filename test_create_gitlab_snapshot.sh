#!/bin/bash

# Define the current timestamp and Unix epoch seconds
CURRENT_DATE=$(date +%Y_%m_%d_%H_%M_%S)
CURRENT_TIMESTAMP=$(date +%s)

# Concatenate them for unique naming
UNIQUE_ID="${CURRENT_DATE}_${CURRENT_TIMESTAMP}"

# Cleanup threshold in seconds (3 days)
CLEANUP_THRESHOLD_SECONDS=$((3 * 24 * 3600)) # 3 days in seconds

# ZFS dataset to snapshot
DATASET="storage01"

# Base path for mount points
MOUNT_BASE="/mnt/zfs_snapshot_${UNIQUE_ID}"

# Create a snapshot
create_snapshot() {
    local snapshot_name="${DATASET}@snapshot_${UNIQUE_ID}"
    /usr/sbin/zfs snapshot $snapshot_name
    echo "Snapshot $snapshot_name created."
}

# Clone and mount the snapshot
clone_and_mount() {
    local clone_name="${DATASET}/clone_${UNIQUE_ID}"
    local mount_path="${MOUNT_BASE}"
    /usr/sbin/zfs clone "${DATASET}@snapshot_${UNIQUE_ID}" $clone_name
    mkdir -p $mount_path
    /usr/sbin/zfs set mountpoint=$mount_path $clone_name
    echo "Clone $clone_name mounted at $mount_path."
}

# Cleanup old snapshots and clones
cleanup_old_resources() {
    # Clean up old clones
    /usr/sbin/zfs list -H -o name -t filesystem | grep "^${DATASET}/clone_" | while read clone; do
        local clone_epoch=$(echo $clone | rev | cut -d'_' -f1 | rev)
        if [[ "$(($CURRENT_TIMESTAMP - clone_epoch))" -gt "$CLEANUP_THRESHOLD_SECONDS" ]]; then
            /usr/sbin/zfs umount $clone
            /usr/sbin/zfs destroy $clone
            echo "Clone $clone has been destroyed."
        fi
    done

    # Clean up old snapshots
    /usr/sbin/zfs list -H -o name -t snapshot | grep "^${DATASET}@snapshot_" | while read snapshot; do
        local snapshot_epoch=$(echo $snapshot | rev | cut -d'_' -f1 | rev)
        if [[ "$(($CURRENT_TIMESTAMP - snapshot_epoch))" -gt "$CLEANUP_THRESHOLD_SECONDS" ]]; then
            /usr/sbin/zfs destroy $snapshot
            echo "Snapshot $snapshot has been destroyed."
        fi
    done
}

# Cleanup old paths
cleanup_old_paths() {
    # Clean up old paths
    ls /mnt | grep "^zfs_snapshot_" | while read path; do
        local path_epoch=$(echo $path | rev | cut -d'_' -f1 | rev)
        if [[ "$(($CURRENT_TIMESTAMP - path_epoch))" -gt "$CLEANUP_THRESHOLD_SECONDS" ]]; then
            echo "Path $path should be remove."
            /usr/bin/rm -rf /mnt/$path
            echo "Path $path has been removed."
        fi
    done
}

remove_gitlab_container() {
    # 检查容器是否存在
    if docker ps -a | grep -q shjd-gitlab-main-geo-n-1; then
        # 如果容器存在，则删除它
        docker rm -f shjd-gitlab-main-geo-n-1
        echo "已删除 GitLab 容器 shjd-gitlab-main-geo-n-1"
    else
        # 如果容器不存在，则输出消息并跳过删除操作
        echo "GitLab 容器 shjd-gitlab-main-geo-n-1 不存在，无需删除"
    fi

    if docker ps -a | grep -q shjd-gitlab-game-geo-n-1; then
        # 如果容器存在，则删除它
        docker rm -f shjd-gitlab-game-geo-n-1
        echo "已删除 GitLab 容器 shjd-gitlab-game-geo-n-1"
    else
        # 如果容器不存在，则输出消息并跳过删除操作
        echo "GitLab 容器 shjd-gitlab-game-geo-n-1 不存在，无需删除"
    fi
}

run_gitlab_container() {
    # 使用`date`命令动态设置当前日期
    GITLAB_HOME="/mnt/zfs_snapshot_$UNIQUE_ID/gitlab-main/geo"

    # 导出GITLAB_HOME环境变量，以便在Docker命令中使用
    export GITLAB_HOME

    # 运行GitLab EE Docker容器
    docker run --detach --hostname shjd-gitlab-main-geo-n-1.bilibili.co --net=fish-net --ip=172.27.0.246 --name shjd-gitlab-main-geo-n-1 --restart always --volume $GITLAB_HOME/config:/etc/gitlab --volume $GITLAB_HOME/logs:/var/log/gitlab  --volume $GITLAB_HOME/data:/var/opt/gitlab  --shm-size 16384m  --add-host=shjd-gitlab-main-geo-n-1.bilibili.co:127.0.0.1 registry.gitlab.cn/omnibus/gitlab-jh:14.10.5

    GITLAB_HOME="/mnt/zfs_snapshot_$UNIQUE_ID/gitlab-game/geo"

    # 导出GITLAB_HOME环境变量，以便在Docker命令中使用
    export GITLAB_HOME

    # 运行GitLab EE Docker容器
    docker run --detach --hostname shjd-gitlab-game-geo-n-1.bilibili.co --net=fish-net --ip=172.27.0.241 --name shjd-gitlab-game-geo-n-1 --restart always --volume $GITLAB_HOME/config:/etc/gitlab --volume $GITLAB_HOME/logs:/var/log/gitlab  --volume $GITLAB_HOME/data:/var/opt/gitlab  --shm-size 16384m  --add-host=shjd-gitlab-game-geo-n-1.bilibili.co:127.0.0.1 registry.gitlab.cn/omnibus/gitlab-jh:15.7.5

}

# Execute functions
remove_gitlab_container
create_snapshot
clone_and_mount
cleanup_old_resources
cleanup_old_paths
run_gitlab_container
