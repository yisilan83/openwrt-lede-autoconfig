#!/bin/bash

# Execute after install feeds
# patch -> [update & install feeds] -> custom -> config

echo "Current dir: $(pwd), Script: $0"

if [ -z "${GITHUB_WORKSPACE}" ]; then
    echo "GITHUB_WORKSPACE not set"
    GITHUB_WORKSPACE=$(
        cd $(dirname $0)/../..
        pwd
    )
    export GITHUB_WORKSPACE
fi

source $GITHUB_WORKSPACE/lib.sh

target=$1
echo "Execute common custom.sh ${target}"

target_array=(${target//-/ })
build_source=${target_array[0]}
build_type=${target_array[1]}
build_target=${target_array[2]}
build_arch=${target_array[3]}
echo "source=${build_source}, type=${build_type}, target=${build_target}, arch=${build_arch}"

# Priority: package dir > feeds dir
do_common() {
    # Set banner
    echo " Built on $(date +%Y-%m-%d)" >>files/etc/banner
    echo "" >>files/etc/banner
    mv -f files/etc/banner package/base-files/files/etc/banner

    # add luci-theme-argon-jerrykuku
    rm -rf package/luci-theme-argon-jerrykuku
    dl_git https://github.com/jerrykuku/luci-theme-argon package/luci-theme-argon-jerrykuku

    # add/replace feeds/luci/applications/luci-app-mosdns
    rm -rf package/luci-app-mosdns
    dl_git_sub https://github.com/sbwml/luci-app-mosdns package/luci-app-mosdns luci-app-mosdns v5

    # replace feeds/helloworld/mosdns, feeds/packages/net/mosdns
    rm -rf package/mosdns
    dl_git_sub https://github.com/sbwml/luci-app-mosdns package/mosdns mosdns v5
    rm -rf package/mosdns/patches
    sed -i 's#IrineSistiana/mosdns/tar#alecthw/mosdns/tar#g' package/mosdns/Makefile
    sed -i 's/^PKG_HASH.*/PKG_HASH:=skip/g' package/mosdns/Makefile

    # add openclash | replace feeds/luci/applications/luci-app-openclash
    rm -rf package/luci-app-openclash
    dl_git_sub https://github.com/vernesong/OpenClash package/luci-app-openclash luci-app-openclash master
    sed -i "/dashboard_password/d" package/luci-app-openclash/root/etc/uci-defaults/luci-openclash

    # add luci-app-fancontrol
    rm -rf package/luci-app-fancontrol
    dl_git_sub https://github.com/rockjake/luci-app-fancontrol package/luci-app-fancontrol luci-app-fancontrol
    rm -rf package/fancontrol
    dl_git_sub https://github.com/rockjake/luci-app-fancontrol package/fancontrol fancontrol

    # add luci-app-tailscale-community
    rm -rf package/luci-app-tailscale-community
    dl_git_sub https://github.com/Tokisaki-Galaxy/luci-app-tailscale-community package/luci-app-tailscale-community luci-app-tailscale-community main

    # add tailscale custom package
    rm -rf package/tailscale
    mkdir -p package/tailscale/files
    cat > package/tailscale/Makefile <<'MAKEFILE_EOF'
include $(TOPDIR)/rules.mk

PKG_NAME:=tailscale
PKG_VERSION:=1.98.3
PKG_RELEASE:=1
PKG_LICENSE:=BSD-3-Clause
PKG_LICENSE_FILES:=LICENSE

include $(INCLUDE_DIR)/package.mk

define Package/tailscale
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=VPN
  TITLE:=Zero config VPN (pre-built binary)
  URL:=https://tailscale.com
  DEPENDS:=+ca-bundle +kmod-tun
endef

define Package/tailscale/description
 Tailscale pre-built binary version $(PKG_VERSION)
endef

define Build/Prepare
endef

define Build/Compile
endef

define Package/tailscale/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DIR) $(1)/etc/tailscale
	$(INSTALL_BIN) ./tailscale $(1)/usr/sbin/
	$(INSTALL_BIN) ./tailscaled $(1)/usr/sbin/
	$(INSTALL_BIN) ./files/tailscale.init $(1)/etc/init.d/tailscale
	$(INSTALL_DATA) ./files/tailscale.conf $(1)/etc/config/tailscale
endef

$(eval $(call BuildPackage,tailscale))
MAKEFILE_EOF

    cat > package/tailscale/files/tailscale.init <<'INIT_EOF'
#!/bin/sh /etc/rc.common

START=90
STOP=10
USE_PROCD=1

start_service() {
    procd_open_instance
    procd_set_param command /usr/sbin/tailscaled
    procd_set_param env TS_DEBUG_FIREWALL_MODE=auto
    procd_set_param limits nofile="65536 65536"
    procd_set_param respawn
    procd_close_instance
}

stop_service() {
    /usr/sbin/tailscale down 2>/dev/null
}
INIT_EOF

    cat > package/tailscale/files/tailscale.conf <<'CONF_EOF'
config tailscale 'config'
    option enabled '0'
    option port '41641'
    option args ''
CONF_EOF

    chmod 755 package/tailscale/files/tailscale.init
}

# excute
do_common

# excute custom for different source
source "$GITHUB_WORKSPACE/user/common/${build_source}.sh"
