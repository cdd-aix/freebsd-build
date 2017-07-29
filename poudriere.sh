#!/bin/sh -ex
jail=111
jailver=11.1-RELEASE
jailver2=11.1-RELEASE-p0
conf="/usr/local/etc/poudriere.conf"
poud="ports-mgmt/poudriere-devel"
init() {
    if [ -z "$(pkg query -e "%o = $poud" %o)" ]; then
	pkg install "$poud"
    else
	pkg upgrade "$poud"
    fi
    mv -v "$conf" "$conf.$(sha256 -q "$conf")"
    cat > "$conf" <<EOF
NO_ZFS=yes
FREEBSD_HOST=https://download.FreeBSD.org
RESOLV_CONF=/etc/resolv.conf
BASEFS=/usr/local/poudriere.nfs
USE_TMPFS=yes
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

    pkg install poudriere-devel
    if [ ! -d /usr/ports/distfiles ]; then
	mkdir -p /usr/ports/distfiles
    fi

    if ! poudriere jail -c -j "$jail" -v "$jailver"; then
	poudriere jail -u -j "$jail" -t "$jailver2" || :
    fi

    if ! poudriere ports -c -p default -c; then
	poudriere ports -p default -u || :
    fi
    cp -p /vagrant/*.conf /usr/local/etc/poudriere.d
}
build() {
    #shellcheck disable=SC2046
    poudriere bulk -j "$jail" -p default -z default $(cat /vagrant/build-patterns/host/*)
}
main() {
    case "$1" in
	init)
	    init
	    build
	    ;;
	build)
	    build
	    ;;
    esac
}
main "$@"
