#!/bin/sh -ex
jail=111
jailver=11.1-RELEASE
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
}

poud() {
    pkg install -y "$poud" git

    mv -v "$conf" "$conf.$(sha256 -q "$conf")"
    cat > "$conf" <<EOF
ZPOOL=poudriere
ZROOTFS=/poudriere
# NO_ZFS=yes
FREEBSD_HOST=https://download.FreeBSD.org
RESOLV_CONF=/etc/resolv.conf
BASEFS=/usr/local/poudriere
USE_TMPFS=no
DISTFILES_CACHE=/usr/ports/distfiles
BAD_PKGNAME_DEPS_ARE_FATAL=yes
CCACHE_DIR=/var/cache/ccache
TIMESTAMP_LOGS=yes
BUILDER_HOSTNAME=bb3.ligonmill.nc.us
PRESERVE_TIMESTAMP=yes
HTML_TRACK_REMAINING=yes
ALLOW_MAKE_JOBS=yes
KEEP_OLD_PACKAGES=yes
PRIORITY_BOOST="llvm* cmake"
EOF
    cp -p /vagrant/*.conf /usr/local/etc/poudriere.d

    mkdir -p /usr/ports/distfiles
    poudriere jail -c -j "$jail" -v "$jailver" || :
    poudriere ports -c -p default -m git || :
}

init() {
    pzfs
    poud
}

build() {
    #shellcheck disable=SC2046
    for b in mf bb3 bb2; do
	poudriere bulk -j "$jail" -p default -z tweak \
		  $(grep -h -v "^#" /vagrant/build-patterns/host/"$b")
    done
}
main() {
    case "$1" in
	init)
	    init
	    ;;
	build)
	    build
	    ;;
    esac
}
main "$@"
