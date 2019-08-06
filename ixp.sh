#!/sbin/env bash

# Set common variables
_irixports_repo="${_irixports_repo:-https://github.com/larb0b/irixports.git}"
_irixports_branch="${_irixports_branch:-master}"
_packaging_prefix="${_packaging_prefix:-/tmp/build}"
_install_prefix="${_install_prefix:-/opt/ixp}"

_pkgname=$1

if [[ -f .config ]] ; then
    . .config
fi

die(){
    local _m="${1}"
    echo "${_m}"
    exit 1
}

precheck(){
    if ! which epm ; then
        die "ERROR: epm is required"
    fi

    if [[ ! -d irixports ]] ; then
        git clone -b "${_irixports_branch}" "${_irixports_repo}"
    fi
}

gen_config(){
    if [[ ! -f irixports/config.sh ]] ; then
        echo "${_packaging_prefix}" > irixports/config.sh
    fi
}

pre_snapshot(){
    find "${_packaging_prefix}" > snapshot.pre
}

build_pkg(){
    pushd "$PWD"
    cd "irixports/${_pkgname}"
    ./package.sh || die "ERROR: build for $_pkgname failed!"
    popd
}

post_snapshot(){
        find "${_packaging_prefix}" > snapshot.post
}

flist_header(){
    cat "${_pkgname}.list" <<EOF
# Directories...
$prefix=${_install_prefix}
$exec_prefix=${_install_prefix}
$bindir=${exec_prefix}/bin
$datarootdir=${_install_prefix}/share
$datadir=${_install_prefix}/share
$docdir=${datadir}/doc/epm
$libdir=${_install_prefix}/lib
$mandir=${datarootdir}/man
$srcdir=.

# Product information
%product ESP Package Manager
%copyright 1999-2017 by Michael R Sweet, All Rights Reserved.
%vendor Easy Software Products
%license ${srcdir}/COPYING
%readme ${srcdir}/README.md
%description Universal software packaging tool for UNIX.
%version 4.4 440
EOF
}

gen_specfile(){
    echo
}

main(){
    pre_check
    gen_config
    pre_snapshot
    build_pkg
    post_snapshot

}

main