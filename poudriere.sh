#!/bin/sh -eux
jail=111
jailver=11.1-RELEASE
ports=default
set=tweak
# jailver2=11.1-RELEASE-p0
conf="/usr/local/etc/poudriere.conf"
poud="ports-mgmt/poudriere-devel"


pzfs() {
    POOL=poudriere
    if ! zfs list "$POOL"; then
	gpart destroy -F ada1 || :
	gpart create -s gpt ada1
	gpart add -t freebsd-zfs -a4k -b1m ada1
	gnop create -S4k ada1
	zpool create -f -d -O atime=off "$POOL" /dev/ada1.nop
	for ZFSFEATURE in \
	    async_destroy empty_bpobj lz4_compress spacemap_histogram \
	    enabled_txg extensible_dataset bookmarks filesystem_limits \
	    large_blocks; do
	    zpool set feature@$ZFSFEATURE=enabled "$POOL"
	done
	zfs set compression=lz4 poudriere
	zpool export poudriere
	gnop destroy /dev/ada1.nop
	zpool import poudriere
    fi
    if [ "$(sysrc -n zfs_enable)" = "NO" ]; then
	sysrc zfs_enable=YES
	zfs import | while read -r pool; do
	    zfs import "$pool"
	done
    fi
    if [ ! -e "/dev/zvol/$POOL/swap" ]; then
	zfs create -V 4G -o org.freebsd:swap=on -o checksum=off -o compression=off -o dedup=off -o sync=disabled -o primarycache=none "$POOL/swap"
	swapon "/dev/zvol/$POOL/swap"
    fi

}

poud() {
    pkg install -q -y "$poud" git

    mv -v "$conf" "$conf.$(sha256 -q "$conf")"
    cat > "$conf" <<EOF
ZPOOL=poudriere
ZROOTFS=/poudriere
# NO_ZFS=yes
FREEBSD_HOST=https://download.FreeBSD.org
RESOLV_CONF=/etc/resolv.conf
BASEFS=/usr/local/poudriere
USE_TMPFS=yes
DISTFILES_CACHE=/usr/ports/distfiles
CHECK_CHANGED_OPTIONS=verbose
BAD_PKGNAME_DEPS_ARE_FATAL=yes
CCACHE_DIR=/var/cache/ccache
TIMESTAMP_LOGS=yes
BUILDER_HOSTNAME=bb3.ligonmill.nc.us
PRESERVE_TIMESTAMP=yes
HTML_TRACK_REMAINING=yes
ALLOW_MAKE_JOBS=yes
KEEP_OLD_PACKAGES=yes
PRIORITY_BOOST="llvm*"
CHECK_CHANGED_OPTIONS=verbose
EOF

    mkdir -p /usr/ports/distfiles
    poudriere jail -c -j "$jail" -v "$jailver" || :
    poudriere ports -c -p "$ports" -m git || :
    cp -pr /vagrant/*.conf* /usr/local/etc/poudriere.d

    for d in /usr/local/etc/poudriere.d/*.conf.d; do
	e="${d%.d}"
	cat "$d"/* > "${e}"
    done
}

init() {
    pzfs
    poud
}

build() {
    poudriere bulk -v -j "$jail" -p "$ports" -z "$set" www/hs-yesod-core
    poudriere bulk -v -j "$jail" -p "$ports" -z "$set" www/hs-DAV
    poudriere bulk -v -j "$jail" -p "$ports" -z "$set" devel/hs-git-annex
    tobuild=$(grep -h -v '^#' /vagrant/build-patterns/host/*)
    # shellcheck disable=SC2086
    poudriere bulk -v -j "$jail" -p "$ports" -z "$set" $tobuild
}

clean() {
    poudriere pkgclean -A -j "$jail" -p "$ports" -z "$set" -y
}

update() {
    poudriere ports -p "$ports" -u
}
main() {
    case "$1" in
	init)
	    init
	    ;;
	build)
	    build
	    ;;
	clean)
	    clean
	    ;;
	update)
	    update
	    ;;
    esac
}
main "$@"
