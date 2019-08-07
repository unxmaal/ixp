#!/usr/bin/env bash
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

    mkdir -p "$_packaging_prefix"
}

gen_config(){
    if [[ ! -f irixports/config.sh ]] ; then
        cat <<EOF > irixports/config.sh
prefix="$_packaging_prefix"
EOF
    fi
}

pre_snapshot(){
    find "${_packaging_prefix}" > snapshot.pre
}


build_pkg(){
    _wd="$PWD"
    cd "irixports/${_pkgname}" || die 
    
    # import vars from package.sh
    source ./package.sh
    unset files
    _product="$port"
    _version="$version"

    ./package.sh || die "ERROR: build for $_pkgname failed!"
    cd "$_wd" || die
}

post_snapshot(){
        find "${_packaging_prefix}" > snapshot.post
}

flist_header(){
    cat  <<EOF > "${_pkgname}.list"
# Directories...
\$prefix=${_install_prefix}
\$exec_prefix=${_install_prefix}
\$bindir=\${exec_prefix}/bin
\$datarootdir=${_install_prefix}/share
\$datadir=${_install_prefix}/share
\$docdir=\${datadir}/doc/epm
\$libdir=${_install_prefix}/lib
\$mandir=\${datarootdir}/man
\$srcdir=.

# Product information
%product ${_product}
%copyright 2019 SGUG
%vendor SGUG
%license null
%readme null
%description null
%version ${_version}
EOF
}

gen_specfile(){
    flist_header
}

main(){
    precheck
    gen_config
    pre_snapshot
    build_pkg
    post_snapshot
    gen_specfile
}

main
