#!/usr/bin/env bash

# NOTE set #!/sbin/env bash if you must.

# Set common variables
_irixports_repo="${_irixports_repo:-https://github.com/larb0b/irixports.git}"
_irixports_branch="${_irixports_branch:-master}"
_packaging_prefix="${_packaging_prefix:-/usr/ixp}"

_action=$1
_pkgname=$2

if [[ -z "$_action" ]] ; then 
    echo "Usage: ./ixp.sh <action> <portname>"
    echo "      Actions:"
    echo "          list = list available irixports ports"
    echo "          build = build port"
    echo "          clean = clean up"
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
    if ! which epm > /dev/null 2>&1; then
        die "ERROR: epm is required"
    fi

    if [[ ! -d irixports ]] ; then
        git clone -b "${_irixports_branch}" "${_irixports_repo}"
    fi

    mkdir -p "$_packaging_prefix"
}

gen_config(){
    if [[ ! -f irixports/config.sh ]] ; then
        echo "config.sh not detected."
        echo "Creating irixports/config.sh . Delete this later if needed."
        cat <<EOF > irixports/config.sh
prefix="$_packaging_prefix"
EOF
    fi
}

pre_snapshot(){
    find "${_packaging_prefix}" > "${_pkgname}.snapshot.pre"
}


build_pkg(){
    _wd="$PWD"
    cd "irixports/${_pkgname}" || die 
    
    # import vars from package.sh
    source ./package.sh
    unset files
    _product="${port:-null}"
    _version="${version:-1.0.0}"

    ./package.sh || die "ERROR: build for $_pkgname failed!"
    cd "$_wd" || die
}

post_snapshot(){
    find "${_packaging_prefix}" > "${_pkgname}.snapshot.post"
}

find_file(){
    local _f="${1}"
    local _t="${2}"
    _p=$(find "./irixports/${_pkgname}/." -name "$_f" | head -n1)
        if [[ -z "$_p" ]] ; then 
            touch "./$_f"
            if [[ "$_t" == "license" ]] ; then
                _license="./$_f"
            elif [[ $_t == "readme" ]] ; then
                _readme="./$_f"
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
    cat  <<EOF > "${_pkgname}.header"
%product ${_product}
%copyright 2019 SGUG
%vendor SGUG
%license "${_license}"
%readme "${_readme}"
%description SGUG Package for "${_pkgname}"
%version ${_version}
EOF
}

gen_diff(){
    diff "${_pkgname}.snapshot.pre" "${_pkgname}.snapshot.post" | grep -v packages.db | grep '>' | awk '{print $2}' > "${_pkgname}.modified.list"
}

run_epm(){
    python spec.py -h "${_pkgname}.header" -t -p "${_pkgname}" -f $(cat "${_pkgname}.modified.list") -e
}

gen_specfile(){
    flist_header
}

save_filelist(){
    mkdir -p "${_pkgname}.info"
    if [[ -f "${_pkgname}.modified.list" ]] ; then
        mv "${_pkgname}.modified.list" "${_pkgname}.info"
    fi
}

cleanup(){
    _wd="$PWD"
    cd "irixports/${_pkgname}" || die 
    ./package.sh clean|| die "ERROR: cleanup for $_pkgname failed!"
    cd "$_wd" || die
}

list_ports(){
    precheck
    ls -1 irixports/ | egrep -v "LICENSE|README.md|*.sh"
}

main(){
    precheck
    gen_config
    pre_snapshot
    build_pkg
    post_snapshot
    gen_diff
    find_file LICENSE
    find_file README
    gen_specfile
    run_epm
    cleanup
}

case $_action in
    build)
        echo "Building and installing ${_pkgname}"
        main
        ;;

    list)
        echo "Available ports:"
        list_ports
        ;;

    clean)
        echo "Cleaning up"
        cleanup
        ;;

    *)
        echo "Available ports:"
        list_ports
        ;;

esac
