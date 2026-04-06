#!/bin/bash

#修改默认主题
sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改immortalwrt.lan关联IP
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
#sed -i "s/[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
#添加编译日期标识
sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_MARK-$WRT_DATE')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")

WIFI_SH=$(find ./target/linux/{mediatek/filogic,qualcommax}/base-files/etc/uci-defaults/ -type f -name "*set-wireless.sh")
WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"
if [ -f "$WIFI_SH" ]; then
	#修改WIFI名称
	sed -i "s/BASE_SSID='.*'/BASE_SSID='$WRT_SSID'/g" $WIFI_SH
	#修改WIFI密码
	sed -i "s/BASE_WORD='.*'/BASE_WORD='$WRT_WORD'/g" $WIFI_SH
elif [ -f "$WIFI_UC" ]; then
	#修改WIFI名称
	sed -i "s/ssid='.*'/ssid='$WRT_SSID'/g" $WIFI_UC
	#修改WIFI密码
	sed -i "s/key='.*'/key='$WRT_WORD'/g" $WIFI_UC
	#修改WIFI地区
	sed -i "s/country='.*'/country='CN'/g" $WIFI_UC
	#修改WIFI加密
	sed -i "s/encryption='.*'/encryption='psk2+ccmp'/g" $WIFI_UC
fi

CFG_FILE="./package/base-files/files/bin/config_generate"
#修改默认IP地址
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE
#sed -i "s/[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE
#修改默认主机名
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE

#配置文件修改
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" >> ./.config

#手动调整的插件
if [ -n "$WRT_PACKAGE" ]; then
	echo -e "$WRT_PACKAGE" >> ./.config
fi

#高通平台调整
DTS_PATH="./target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/"
if [[ $WRT_TARGET == *"QUALCOMMAX"* ]]; then
	# ==================== NSS 硬件加速配置 ====================
	# 
	# 当前配置：仅使用 BBR 拥塞控制算法，禁用 NSS 硬件加速
	# 原因：优先考虑稳定性和简单性
	# 
	# NSS（Network Subsystem）是高通 IPQ 芯片的硬件加速系统，性能提升显著：
	# - 千兆环境：可达到线速（940+ Mbps）
	# - 千兆以上：2-5 倍性能提升
	# - CPU 占用：降低 50-80%
	# 
	# 何时应该启用 NSS：
	# - 需要极致性能（2.5G/10G 网络环境）
	# - 需要硬件加速 WiFi
	# - 需要 QoS 硬件加速
	# - 需要防火墙硬件加速
	# 
	# 如何启用 NSS：
	# 1. 将下面的 CONFIG_FEED_nss_packages 从 n 改为 y
	# 2. 将下面的 CONFIG_FEED_sqm_scripts_nss 从 n 改为 y
	# 3. 确保启用 NSS 版本（默认 12.5）
	# 
	# 注意：启用 NSS 可能影响稳定性，建议先测试
	# 
	# ==================== 当前配置：禁用 NSS ====================
	# 取消 nss 相关 feed
	echo "CONFIG_FEED_nss_packages=n" >> ./.config
	echo "CONFIG_FEED_sqm_scripts_nss=n" >> ./.config
	# 设置 NSS 版本
	echo "CONFIG_NSS_FIRMWARE_VERSION_11_4=n" >> ./.config
 	# echo "CONFIG_NSS_FIRMWARE_VERSION_12_2=n" >> ./.config
	echo "CONFIG_NSS_FIRMWARE_VERSION_12_5=y" >> ./.config
	
	# ==================== 启用 NSS 的配置（已注释） ====================
	# 如果需要启用 NSS，请取消下面的注释：
	# echo "CONFIG_FEED_nss_packages=y" >> ./.config      # 启用 NSS 软件包
	# echo "CONFIG_FEED_sqm_scripts_nss=y" >> ./.config   # 启用 SQM NSS 脚本
	# echo "CONFIG_NSS_FIRMWARE_VERSION_12_5=y" >> ./.config  # NSS 版本 12.5
	# 
	# ==================== NSS 配置说明 ====================
	# NSS 版本说明：
	# - 11.4：较旧版本，兼容性好
	# - 12.2：中间版本
	# - 12.5：最新版本，功能最全，推荐使用
	# 
	# 性能对比（IPQ60XX + 千兆网络）：
	# - 仅 BBR：800-900 Mbps，CPU 占用 40-60%
	# - 仅 NSS：900-940 Mbps，CPU 占用 10-20%
	# - NSS + BBR：940+ Mbps，CPU 占用 10-20%（最佳性能）
	# 
	# 无 WiFi 配置调整 Q6 大小
	if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
		find $DTS_PATH -type f ! -iname '*nowifi*' -exec sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +
		echo "qualcommax set up nowifi successfully!"
	fi
fi

#编译器优化
if [[ $WRT_TARGET != *"X86"* ]]; then
	echo "CONFIG_TARGET_OPTIONS=y" >> ./.config
	echo "CONFIG_TARGET_OPTIMIZATION=\"-O2 -pipe -march=armv8-a+crypto+crc -mcpu=cortex-a53+crypto+crc -mtune=cortex-a53\"" >> ./.config
fi

# 想要剔除的
# echo "CONFIG_PACKAGE_htop=n" >> ./.config
# echo "CONFIG_PACKAGE_iperf3=n" >> ./.config
echo "CONFIG_PACKAGE_luci-app-wolplus=n" >> ./.config
echo "CONFIG_PACKAGE_luci-app-tailscale=n" >> ./.config
echo "CONFIG_PACKAGE_luci-app-advancedplus=n" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-kucat=n" >> ./.config

# 可以让FinalShell查看文件列表并且ssh连上不会自动断开
echo "CONFIG_PACKAGE_openssh-sftp-server=y" >> ./.config
# Bandix 网络流量监控后端
echo "CONFIG_PACKAGE_bandix=y" >> ./.config
#Bandix 网络流量监控前端
echo "CONFIG_PACKAGE_luci-app-bandix=y" >> ./.config
# 解析、查询、操作和格式化 JSON 数据
echo "CONFIG_PACKAGE_jq=y" >> ./.config
# 简单明了的系统资源占用查看工具
echo "CONFIG_PACKAGE_btop=y" >> ./.config
# 多网盘存储
#echo "CONFIG_PACKAGE_luci-app-alist=y" >> ./.config
# ftp工具
#echo "CONFIG_PACKAGE_luci-app-vsftpd=y" >> ./.config
# 断网检测功能与定时重启
#echo "CONFIG_PACKAGE_luci-app-watchcat=y" >> ./.config
# 下载工具
# echo "CONFIG_PACKAGE_luci-app-aria2=y" >> ./.config
# Docker
# echo "CONFIG_PACKAGE_luci-app-docker=y" >> ./.config
# Passwall
# echo "CONFIG_PACKAGE_luci-app-passwall=y" >> ./.config
# 微信推送
# echo "CONFIG_PACKAGE_luci-app-wechatpush=y" >> ./.config
# 广告屏蔽大师Plus
# echo "CONFIG_PACKAGE_luci-app-adbyby-plus=y" >> ./.config 
# 强大的工具(需要添加源或git clone)
echo "CONFIG_PACKAGE_luci-app-lucky=y" >> ./.config
# 网络通信工具
echo "CONFIG_PACKAGE_curl=y" >> ./.config
# CPU 性能优化调节设置
echo "CONFIG_PACKAGE_luci-app-cpufreq=y" >> ./.config
# Windows激活
echo "CONFIG_PACKAGE_luci-app-vlmcsd=y" >> ./.config
# turboacc
# echo "CONFIG_PACKAGE_luci-app-turboacc=y" >> ./.config

# ==================== 网络优化配置 ====================
# 
# 当前配置：仅启用 BBR 拥塞控制算法
# 硬件加速：NSS 已禁用（见上方注释说明）
# 
# BBR（Bottleneck Bandwidth and Round-trip propagation time）：
# - Google 开发的 TCP 拥塞控制算法
# - 提升网络吞吐量 20-30%
# - 降低网络延迟
# - 通用性强，所有平台支持
# - 稳定可靠，Google 官方支持
# 
# 性能表现（IPQ60XX + 千兆网络）：
# - 仅 BBR：800-900 Mbps，CPU 占用 40-60%
# - 仅 NSS：900-940 Mbps，CPU 占用 10-20%
# - NSS + BBR：940+ Mbps，CPU 占用 10-20%（最佳性能）
# 
# 当前推荐：仅使用 BBR
# 原因：稳定性优先，性能足够，配置简单
# 
# BBR 拥塞控制算法(终端侧)
echo "CONFIG_PACKAGE_kmod-tcp-bbr=y" >> ./.config           # 启用 BBR 模块
echo "CONFIG_DEFAULT_tcp_bbr=y" >> ./.config               # 默认使用 BBR 算法

# ==================== 其他网络优化（已注释） ====================
# CAKE：一种现代化的队列管理算法(路由侧)
#echo "CONFIG_PACKAGE_luci-app-sqm=y" >> ./.config         # SQM 队列管理
#echo "CONFIG_PACKAGE_kmod-sched-cake=y" >> ./.config      # CAKE 队列算法
# 
# turboacc：硬件加速聚合工具
# echo "CONFIG_PACKAGE_luci-app-turboacc=y" >> ./.config   # 硬件加速聚合

# ==================== 配置建议 ====================
# 
# 千兆网络环境（当前推荐）：
# - ✅ 仅 BBR：800-900 Mbps，稳定性高
# 
# 千兆以上网络（追求性能）：
# - 启用 NSS（见上方注释）+ BBR：940+ Mbps
# 
# 需要硬件加速功能：
# - 启用 NSS + BBR：硬件加速 + TCP 优化
# 
# 低延迟需求：
# - BBR + CAKE：降低网络延迟
# 
# docker(只能集成)
#echo "CONFIG_PACKAGE_luci-app-dockerman=y" >> ./.config
