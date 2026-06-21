# MzWrt AX3600 QSDK

基于 [`FanFansfan/qsdk-5.4`](https://github.com/FanFansfan/qsdk-5.4) 自动构建小米 AX3600 固件。

## 默认配置

- 设备：Xiaomi AX3600（IPQ807x / AP-AC04）
- 管理地址：`192.168.88.1`
- 主机名：`MzWRT`
- WiFi 名称：`Mr.Wrt`
- 作者签名：`Mr.Zhang`
- 默认主题：Argon
- 包含：OpenClash
- 不包含：PassWall / PassWall2

## 构建

进入 **Actions → Build MzWRT AX3600 QSDK → Run workflow** 手动启动构建。

构建成功后可在该次运行的 Artifacts 中下载：

- `nand-factory.bin`：适用于对应 U-Boot/刷写流程的工厂镜像
- `nand-sysupgrade.bin`：适用于系统内升级
- 软件包清单、源码版本及 SHA-256 校验值

> 这是旧版 Qualcomm QSDK 5.4 构建树。首次构建可能需要根据已经失效的历史下载源修复依赖。
