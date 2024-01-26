# gitlab-backup
实现n-1天的gitlab备份

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