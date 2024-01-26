#!/bin/bash

# ZFS dataset to snapshot
DATASET="rpool/USERDATA/zhaoyihuan_mfubfx"
# Base path for mount points
MOUNT_BASE="/mnt/zfs_snapshot"

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
create_snapshot
clone_and_mount
cleanup_old_snapshots