# gitlab-backup
简介：可实现n-1天的gitlab备份，利用zfs快照特性,从删除旧的gitlab实例到新的gitlab启动，整个过程通常仅需5分钟左右。

## 先决条件
- Docker
- ZFS(Zettabyte File System)

## 测试环境
- Ubuntu 22.04.3 LTS (Jammy Jellyfish)
- Docker version 24.0.6
- zfs-2.1.5-1ubuntu6~22.04.1
- gitlab-ee:16.8.1-ee.0
- Docker Network 配置
```
docker network create -d ipvlan --subnet 192.168.111.0/24 --gateway 192.168.111.1 -o ipvlan_mode=l2 -o parent=nm-bond fish-net
```
- gitlab数据目录
```
/home/zhaoyihuan/gitlab-ee
```
- zfs挂载点信息
```
zhaoyihuan@fish-server-01 ~/gitlab-ee> df -h  /home/zhaoyihuan/gitlab-ee/                                                     (base)
Filesystem                        Size  Used Avail Use% Mounted on
rpool/USERDATA/zhaoyihuan_mfubfx  590G  296G  295G  51% /home/zhaoyihuan
```
- gitlab 启动命令
```
expor GITLAB_HOME=/home/zhaoyihuan/gitlab-ee
docker run --detach --net=fish-net --ip=192.168.111.240 --hostname git.dapangyu.work --publish 6443:443 --publish 680:80 --publish 622:22 --name gitlab-ee --restart always --volume $GITLAB_HOME/config:/etc/gitlab --volume $GITLAB_HOME/logs:/var/log/gitlab --volume $GITLAB_HOME/data:/var/opt/gitlab --volume $GITLAB_HOME/data:/var/opt/gitlab --shm-size 4096m  --add-host=git.dapangyu.work:192.168.111.240  --add-host=git-standby.dapangyu.work:192.168.111.241  gitlab/gitlab-ee:16.8.1-ee.0
```

# 使用方法
- 将create_gitlab_backup_snapshots.sh 加入到crontab 中即可，需要root用户编辑crontab
```
zhaoyihuan@fish-server-01 ~ [1]> sudo crontab -l                                                                              (base)
0 0 * * * /bin/bash /home/zhaoyihuan/create_gitlab_backup_snapshots.sh
```
