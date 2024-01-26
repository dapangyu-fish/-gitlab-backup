#!/bin/bash

# ZFS dataset to snapshot
DATASET="rpool/USERDATA/zhaoyihuan_mfubfx"
# Base path for mount points
MOUNT_BASE="/mnt/zfs_snapshot"

remove_gitlab_container() {
    if docker ps -a | grep -q gitlab-ee-n-1; then
        docker rm -f gitlab-ee-n-1
        echo "rm container gitlab-ee-n-1 success"
    else
        echo "rm container gitlab-ee-n-1 skiped"
    fi
}


run_gitlab_container() {
    # 使用`date`命令动态设置当前日期
    GITLAB_HOME="/mnt/zfs_snapshot_$(date +%Y_%m_%d)/gitlab-ee"
    
    # 导出GITLAB_HOME环境变量，以便在Docker命令中使用
    export GITLAB_HOME

    # 运行GitLab EE Docker容器
    docker run --detach --net=fish-net --ip=192.168.111.242 --hostname git-n-1.dapangyu.work --publish 6443:443 --publish 680:80 --publish 622:22 --name gitlab-ee-n-1 --restart always --volume $GITLAB_HOME/config:/etc/gitlab --volume $GITLAB_HOME/logs:/var/log/gitlab --volume $GITLAB_HOME/data:/var/opt/gitlab --volume $GITLAB_HOME/license/license.rb:/opt/gitlab/embedded/service/gitlab-rails/ee/app/models/license.rb --volume $GITLAB_HOME/license/.license_encryption_key.pub:/opt/gitlab/embedded/service/gitlab-rails/.license_encryption_key.pub --shm-size 4096m --add-host=version.gitlab.com:127.0.0.1 --add-host=version.gitlab.cn:127.0.0.1 --add-host=git-n-1.dapangyu.work:192.168.111.242 --add-host=git-1.dapangyu.work:192.168.111.240 --add-host=git-standby.dapangyu.work:192.168.111.241 gitlab/gitlab-ee:16.8.1-ee.0
}

# Function to create a snapshot with timestamp
create_snapshot() {
    local timestamp=$(date +%Y_%m_%d)
    local snapshot_name="${DATASET}@snapshot_${timestamp}"
    # Create snapshot
    zfs snapshot $snapshot_name
    echo "Snapshot $snapshot_name created."
}

# Function to clone and mount the snapshot
clone_and_mount() {
    local timestamp=$(date +%Y_%m_%d)
    local clone_name="${DATASET}_snapshot_${timestamp}"
    local mount_path="${MOUNT_BASE}_${timestamp}"
    # Clone the snapshot
    zfs clone "${DATASET}@snapshot_${timestamp}" $clone_name
    # Create mount point and mount the clone
    mkdir -p $mount_path
    zfs set mountpoint=$mount_path $clone_name
    echo "Clone $clone_name mounted at $mount_path."
}

# Function to clean up old snapshots and clones (older than 3 days)
cleanup_old_snapshots() {
    local cutoff_date=$(date --date="3 days ago" +%Y_%m_%d)

    # Handle old clones first
    for clone in $(zfs list -H -o name -t filesystem,volume | grep "^${DATASET}_snapshot_" | sort); do
        local clone_date=$(echo $clone | rev | cut -d'_' -f1-3 | rev | tr '_' '-')
        if [[ "$clone_date" < "$cutoff_date" ]]; then
            # Unmount and destroy old clone
            zfs unmount $clone
            echo "Clone $clone unmounted."
            zfs destroy $clone
            echo "Clone $clone destroyed."

            # Determine and remove the mount path
            local mount_path="${MOUNT_BASE}_${clone_date}"
            rm -rf $mount_path
            echo "Mount path $mount_path removed."
        fi
    done

    # Then, handle old snapshots
    for snapshot in $(zfs list -H -o name -t snapshot | grep "${DATASET}@snapshot_" | sort); do
        local snapshot_date=$(echo $snapshot | cut -d'@' -f2 | cut -d'_' -f2-)
        if [[ "$snapshot_date" < "$cutoff_date" ]]; then
            # Destroy old snapshot
            zfs destroy $snapshot
            echo "Snapshot $snapshot destroyed."
        fi
    done
}

# Main execution
remove_gitlab_container
create_snapshot
clone_and_mount
cleanup_old_snapshots
run_gitlab_container
