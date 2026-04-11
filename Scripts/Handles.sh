#!/bin/bash

PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"

#预置HomeProxy数据
if [ -d *"homeproxy"* ]; then
	HP_RULE="surge"
	HP_PATH="homeproxy/root/etc/homeproxy"

	rm -rf ./$HP_PATH/resources/*

	git clone -q --depth=1 --single-branch --branch "release" "https://github.com/Loyalsoldier/surge-rules.git" ./$HP_RULE/
	cd ./$HP_RULE/ && RES_VER=$(git log -1 --pretty=format:'%s' | grep -o "[0-9]*")

	echo $RES_VER | tee china_ip4.ver china_ip6.ver china_list.ver gfw_list.ver
	awk -F, '/^IP-CIDR,/{print $2 > "china_ip4.txt"} /^IP-CIDR6,/{print $2 > "china_ip6.txt"}' cncidr.txt
	sed 's/^\.//g' direct.txt > china_list.txt ; sed 's/^\.//g' gfw.txt > gfw_list.txt
	mv -f ./{china_*,gfw_list}.{ver,txt} ../$HP_PATH/resources/

	cd .. && rm -rf ./$HP_RULE/

	cd $PKG_PATH && echo "homeproxy date has been updated!"
fi

#修改argon主题字体和颜色
if [ -d *"luci-theme-argon"* ]; then
	cd ./luci-theme-argon/

	sed -i "/font-weight:/ { /important/! { /\/\*/! s/:.*/: var(--font-weight);/ } }" $(find ./luci-theme-argon -type f -iname "*.css")
	sed -i "s/primary '.*'/primary '#5e72e4'/; s/'0.2'/'0.5'/; s/'none'/'Unsplash'/; s/'600'/'normal'/" ./luci-app-argon-config/root/etc/config/argon

	# 添加 wallhaven 壁纸源支持
	# 1. 在前端配置文件中添加 wallhaven 选项
	sed -i $"/o.value('unsplash', _('Unsplash'));/a\\
	o.value('wallhaven', _('Wallhaven'));" ./luci-app-argon-config/htdocs/luci-static/resources/view/argon-config.js

	# 2. 在后端脚本中添加 wallhaven API 调用
	sed -i '/esac/i\
wallhaven)\
\tcurl -s -m 3 \\\
\t\t"https://wallhaven.cc/api/v1/search?resolutions=1920x1080&sorting=random" |\
\t\tjsonfilter -qe "@.data[0].path"\
\t;;\
wallhaven_*)\
\tlocal tag_id="${WEB_PIC_SRC#wallhaven_}"\
\tlocal use_reso="resolutions"\
\t[ "$EXACT_RESO" -eq "1" ] || use_reso="atleast"\
\t[ -z "$API_KEY" ] || API_KEY="apikey=$API_KEY&"\
\tcurl -s -m 3 \\\
\t\t"https://wallhaven.cc/api/v1/search?${API_KEY}q=id%3A${tag_id}&${use_reso}=1920x1080&sorting=random" |\
\t\tjsonfilter -qe '"'"'@.data[0].path'"'"'\
\t;;' ./luci-theme-argon/root/usr/libexec/rpcd/luci.argon_wallpaper

	# 3. 添加配置变量
	sed -i '/WEB_PIC_SRC.*uci -q get/a\
API_KEY="$(uci -q get argon.@global[0].use_api_key)"\
EXACT_RESO="$(uci -q get argon.@global[0].use_exact_resolution || echo '"'"'1'"'"')"' ./luci-theme-argon/root/usr/libexec/rpcd/luci.argon_wallpaper

   # 4. 删除 background/README.md
   rm -f ./luci-theme-argon/htdocs/luci-static/argon/background/README.md

	cd $PKG_PATH && echo "theme-argon has been fixed!"
fi

#修改qca-nss-drv启动顺序
NSS_DRV="../feeds/nss_packages/qca-nss-drv/files/qca-nss-drv.init"
if [ -f "$NSS_DRV" ]; then
	sed -i 's/START=.*/START=85/g' $NSS_DRV

	cd $PKG_PATH && echo "qca-nss-drv has been fixed!"
fi

#修改qca-nss-pbuf启动顺序
NSS_PBUF="./kernel/mac80211/files/qca-nss-pbuf.init"
if [ -f "$NSS_PBUF" ]; then
	sed -i 's/START=.*/START=86/g' $NSS_PBUF

	cd $PKG_PATH && echo "qca-nss-pbuf has been fixed!"
fi

#移除Shadowsocks组件
PW_FILE=$(find ./ -maxdepth 3 -type f -wholename "*/luci-app-passwall/Makefile")
if [ -f "$PW_FILE" ]; then
	sed -i '/config PACKAGE_$(PKG_NAME)_INCLUDE_Shadowsocks_Libev/,/x86_64/d' $PW_FILE
	sed -i '/config PACKAGE_$(PKG_NAME)_INCLUDE_ShadowsocksR/,/default n/d' $PW_FILE
	sed -i '/Shadowsocks_NONE/d; /Shadowsocks_Libev/d; /ShadowsocksR/d' $PW_FILE

	cd $PKG_PATH && echo "passwall has been fixed!"
fi

SP_FILE=$(find ./ -maxdepth 3 -type f -wholename "*/luci-app-ssr-plus/Makefile")
if [ -f "$SP_FILE" ]; then
	sed -i '/default PACKAGE_$(PKG_NAME)_INCLUDE_Shadowsocks_Libev/,/libev/d' $SP_FILE
	sed -i '/config PACKAGE_$(PKG_NAME)_INCLUDE_ShadowsocksR/,/x86_64/d' $SP_FILE
	sed -i '/Shadowsocks_NONE/d; /Shadowsocks_Libev/d; /ShadowsocksR/d' $SP_FILE

	cd $PKG_PATH && echo "ssr-plus has been fixed!"
fi

#修复TailScale配置文件冲突
TS_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/tailscale/Makefile")
if [ -f "$TS_FILE" ]; then
	sed -i '/\/files/d' $TS_FILE

	cd $PKG_PATH && echo "tailscale has been fixed!"
fi

#修复Coremark编译失败
CM_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/coremark/Makefile")
if [ -f "$CM_FILE" ]; then
	sed -i 's/mkdir/mkdir -p/g' $CM_FILE

	cd $PKG_PATH && echo "coremark has been fixed!"
fi
