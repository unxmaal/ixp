#!/usr/bin/env bash
#!/sbin/env bash

# Set common variables
_irixports_repo="${_irixports_repo:-https://github.com/larb0b/irixports.git}"
_irixports_branch="${_irixports_branch:-master}"
_packaging_prefix="${_packaging_prefix:-/opt/ixp}"

_pkgname=$1
if [[ -z "$_pkgname" ]] ; then 
    echo "Usage: ./ixp.sh <portname>"
    exit 0
fi

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
    _product="$port:-null"
    _version="$version:-1.0.0"

    ./package.sh || die "ERROR: build for $_pkgname failed!"
    cd "$_wd" || die
}

post_snapshot(){
    find "${_packaging_prefix}" > snapshot.post
}

find_file(){
    local _f="${1}"
    local _t="${2}"
    _p=$(find "./irixports/${_pkgname}/." -name "$_f" | head -n1)
        if [[ -z "$_p" ]] ; then 
            touch "$_p"
            if [[ "$_t" == "license" ]] ; then
                _license="$_p"
            elif [[ $_t == "readme" ]] ; then
                _readme="$_p"
            fi
        else
            if [[ "$_t" == "license" ]] ; then
                _license="$_p"
            elif [[ $_t == "readme" ]] ; then
                _readme="$_p"
            fi
        fi
}

flist_header(){
    cat  <<EOF > "header"
%product ${_product}
%copyright 2019 SGUG
%vendor SGUG
%license "${_license}"
%readme "${_readme}"
%description SGUG Package for "${_pkgname}"
%version ${_version}
EOF
}

run_epm(){
    python spec.py -h header -t -p "${_pkgname}" -e $(cat snapshot.post) 
}

gen_specfile(){
    flist_header
}

cleanup(){
    _wd="$PWD"
    cd "irixports/${_pkgname}" || die 
    ./package.sh clean|| die "ERROR: cleanup for $_pkgname failed!"
    cd "$_wd" || die
}

main(){
    precheck
    gen_config
    pre_snapshot
    build_pkg
    post_snapshot
    find_file LICENSE
    find_file README
    gen_specfile
    run_epm
}

main
