#!/bin/sh

REQ_PROG="basename rpmbuild sha256sum tar wget"
echo "Checking for required programs..."
for prog in ${REQ_PROGS};
do
    if [ ! $(which ${prog}) ]; then
        echo "Script requires ${prog}"
        exit 1
    fi
done
echo

function show_usage() {
    echo "Usage: run.sh [COMMAND] [OPTIONS] GCC_VERSION"
    echo "  Commands:"
    echo "    urls       Print urls of files needed and exit"
    echo "  Options:"
    echo "    -h --help  Show this message"
    echo "    --offline  Do not attempt to download files"
}

if [ "$#" = "0" ]; then
    show_usage
    exit 0
fi

for arg in "$@"
do
    case "${arg}" in
        -h | --help | -?)
            show_usage
            exit 0
            ;;
        urls)
            PRINT_URLS=y
            ;;
        --offline)
            OFFLINE=y
            ;;
        [0-9] | [0-9].[0-9]* | [0-9]*.[0-9]*.[0-9]*)
            GCC_VER=${GCC_VER:-"${arg}"}
            ;;
        *)
            >&2 echo "Ignoring unrecognized argument ${arg}"
            ;;
    esac
done

if [ -z "${GCC_VER}" ]; then
    >&2 echo "No GCC version present on command-line"
    show_usage
    exit 1
fi

if [ ! -e files ]; then
    if [ -z "${OFFLINE}" ]; then
        >&2 echo "No files list present, fetching from CentOS Vault..."
        source updateVersions.sh
    else
        >&2 echo "No files list present and in offline mode."
        >&2 echo "Run ./updateVersions.sh"
        exit 1
    fi
fi

# Check for requested GCC version in filelist
if ! grep gcc-${GCC_VER} files > /dev/null ; then
    >&2 echo "No matching gcc found for version ${GCC_VER}"
    exit 1
fi

# The following line does not adequately handle updates to the default GCC package and the contents
# of devtoolset-3 when the user asks for GCC 4. If the default GCC package has been updated in the
# most recent point release of CentOS, asking for GCC 4 will give you the GCC 4.8 series compiler
# instead of the more recent GCC 4.9 series compiler from devtoolset-3. I'm not concerned enough to
# fix it. You want a 4.9 series compiler, ask for it specifically.
GCC_RPM=$(grep gcc-${GCC_VER} files | sort -V | tail -n 1)
GCC_VER=$(basename "${GCC_RPM}" | grep -o -e 'gcc-[0-9]\+\(\.[0-9]\+\)*' | cut -d '-' -f 2)

CENTOS_VER=$(echo "${GCC_RPM}" | cut -d '/' -f 2)

if echo "${GCC_RPM}" | grep devtoolset > /dev/null ; then
    DEVTOOLSET=$(basename "${GCC_RPM}" | cut -d '-' -f 2)
    BINUTILS_RPM=$(grep "${CENTOS_VER}/sclo/Source/rh/devtoolset-${DEVTOOLSET}/devtoolset-${DEVTOOLSET}-binutils" files | sort -V | tail -n 1)
    BINUTILS_VER=$(basename ${BINUTILS_RPM} | cut -d '-' -f 4)
else
    BINUTILS_RPM=$(grep "${CENTOS_VER}/\(os\|updates\)/Source/SPackages/binutils" files | sort -V | tail -n 1)
    BINUTILS_VER=$(basename ${BINUTILS_RPM} | cut -d '-' -f 2)
fi
GETTEXT_RPM=$(grep "${CENTOS_VER}/\(os\|updates\)/Source/SPackages/gettext" files | sort -V | tail -n 1)
GETTEXT_VER=$(basename ${GETTEXT_RPM} | cut -d '-' -f 2)
GLIBC_RPM=$(grep "${CENTOS_VER}/\(os\|updates\)/Source/SPackages/glibc" files | sort -V | tail -n 1)
GLIBC_VER=$(basename ${GLIBC_RPM} | cut -d '-' -f 2)
GMP_RPM=$(grep "${CENTOS_VER}/\(os\|updates\)/Source/SPackages/gmp" files | sort -V | tail -n 1)
GMP_VER=$(basename ${GMP_RPM} | cut -d '-' -f 2)
LIBMPC_RPM=$(grep "${CENTOS_VER}/\(os\|updates\)/Source/SPackages/libmpc" files | sort -V | tail -n 1)
LIBMPC_VER=$(basename ${LIBMPC_RPM} | cut -d '-' -f 2)
MPFR_RPM=$(grep "${CENTOS_VER}/\(os\|updates\)/Source/SPackages/mpfr" files | sort -V | tail -n 1)
MPFR_VER=$(basename ${MPFR_RPM} | cut -d '-' -f 2)
NCURSES_RPM=$(grep "${CENTOS_VER}/\(os\|updates\)/Source/SPackages/ncurses" files | sort -V | tail -n 1)
NCURSES_VER=$(basename ${NCURSES_RPM} | cut -d '-' -f 2)

function print_versions() {
    echo -n "Using CentOS ${CENTOS_VER} "
    if [ ! -z ${DEVTOOLSET} ]; then
       echo -n "Devtoolset ${DEVTOOLSET}"
    fi
    echo
    echo

    printf "   Tool       Version\n"
    printf "==========   =========\n"
    printf "binutils*    %9s\n" ${BINUTILS_VER}
    printf "gcc*         %9s\n" ${GCC_VER}
    printf "gettext      %9s\n" ${GETTEXT_VER}
    printf "glibc        %9s\n" ${GLIBC_VER}
    printf "gmp          %9s\n" ${GMP_VER}
    printf "libmpc       %9s\n" ${LIBMPC_VER}
    printf "mpfr         %9s\n" ${MPFR_VER}
    printf "ncurses      %9s\n" ${NCURSES_VER}
    echo
    echo "* these packages may differ based on devtoolset"
    echo
}

function print_rpm_urls() {
    cat << EOF | sed 's/^\./http:\/\/vault.centos.org/'
${BINUTILS_RPM}
${GCC_RPM}
${GETTEXT_RPM}
${GLIBC_RPM}
${GMP_RPM}
${LIBMPC_RPM}
${MPFR_RPM}
${NCURSES_RPM}
EOF
}

if [ ! -z "${PRINT_URLS}" ]; then
    print_rpm_urls
    exit
fi

print_versions

if [ ! -z "${OFFLINE}" ]; then
    echo "Checking for necessary files..."
    for url in $(print_rpm_urls)
    do
        if [ ! -e srpms/$(basename ${url}) ]; then
            >&2 echo "Missing $(basename ${url})"
            MISSING=y
        fi
    done
    if [ ! -z "${MISSING}" ]; then
        >&2 "Missing one or more required files. Aborting..."
        exit 1
    fi
else
    echo "Downloading RPMs from CentOS Vault..."
    mkdir -p srpms
    pushd srpms > /dev/null
    print_rpm_urls | wget -N -c --quiet -i - > /dev/null
    popd > /dev/null
    echo
fi

echo "Unpacking RPMs to rpmbuild tree..."
rm -rf rpmbuild
mkdir -p rpmbuild/{SOURCES,SPECS}
for rpm in $(print_rpm_urls)
do
    pushd rpmbuild/SOURCES > /dev/null
    rpm2cpio ../../srpms/$(basename ${rpm}) | cpio -idm --quiet
    popd > /dev/null
done
mv rpmbuild/SOURCES/*.spec rpmbuild/SPECS/.
echo

echo "Running %prep portion of rpm specs..."
pushd rpmbuild > /dev/null
for spec in SPECS/*
do
    rpmbuild --define "_topdir $(pwd)" --nodeps --quiet -bp ${spec} > /dev/null
done
popd > /dev/null
echo

echo "Creating simple tarballs..."
mkdir -p tarballs
pushd rpmbuild/BUILD > /dev/null
BINUTILS_TAR=$(ls | grep binutils).tar.gz
tar zcf ../../tarballs/${BINUTILS_TAR} binutils*
GCC_TAR=$(ls | grep gcc).tar.gz
tar zcf ../../tarballs/${GCC_TAR} gcc*
GETTEXT_TAR=$(ls | grep gettext).tar.gz
tar zcf ../../tarballs/${GETTEXT_TAR} gettext*
GLIBC_TAR=$(ls | grep glibc).tar.gz
tar zcf ../../tarballs/${GLIBC_TAR} glibc*
GMP_TAR=$(ls | grep gmp).tar.gz
tar zcf ../../tarballs/${GMP_TAR} gmp*
MPC_TAR=$(ls | grep mpc).tar.gz
tar zcf ../../tarballs/${MPC_TAR} mpc*
MPFR_TAR=$(ls | grep mpfr).tar.gz
tar zcf ../../tarballs/${MPFR_TAR} mpfr*
NCURSES_TAR=$(ls | grep ncurses).tar.gz
tar zcf ../../tarballs/${NCURSES_TAR} ncurses*
pushd gcc* > /dev/null
ISL_TAR=$(ls | grep isl).tar.gz
if [ "${ISL_TAR}" != ".tar.gz" ]; then
    ISL_VER=$(echo ${ISL_TAR} | grep -o -e '[0-9]\(\.[0-9]\+\)*')
    tar zcf ../../../tarballs/${ISL_TAR} isl*
else
    unset ISL_TAR
fi
popd > /dev/null
popd > /dev/null
# for GCC 4, CLooG
if [ "$(echo ${GCC_VER} | cut -d '.' -f 1)" = "4" ]; then
    pushd rpmbuild/SOURCES > /dev/null
    CLOOG_TAR=$(ls cloog*.tar.gz)
    CLOOG_VER=$(echo ${CLOOG} | grep -o -e '[0-9]\(\.[0-9]\+\)*')
    cp ${CLOOG_TAR} ../../tarballs/.
    popd > /dev/null
fi
echo

echo "Cleaning up intermediate files..."
rm -rf rpmbuild

echo "Getting crosstool-ng and configuring..."
if [ ! -z "${OFFLINE}" ]; then
    if [ ! -d crosstool-ng ]; then
        >&2 echo "No Crosstool NG checkout present in offline mode"
        exit 1
    fi
else
    git clone https://github.com/crosstool-ng/crosstool-ng
    pushd crosstool-ng > /dev/null
    git reset --hard d5900deb
    popd > /dev/null
fi
pushd crosstool-ng > /dev/null
git apply ../patches/crosstool-ng_ncurses_build.patch

if [ ! -e configure ]; then
    ./bootstrap
fi
if [ ! -e Makefile ]; then
    ./configure --enable-local
fi
if [ ! -e ct-ng ]; then
    make
fi

cat << EOF > defconfig
# crosstool-NG behavior
CT_OBSOLETE=y
CT_EXPERIMENTAL=y

`if [ ! -z "${OFFLINE}" ]; then
    echo "CT_FORBID_DOWNLOAD=y"
fi
`

# Tuple completion and aliasing
CT_TARGET_VENDOR="centos7"

# Operating System
CT_KERNEL_LINUX=y

# Binary utilities
CT_BINUTILS_BINUTILS=y
CT_BINUTILS_SRC_CUSTOM=y
CT_BINUTILS_CUSTOM_LOCATION="\${CT_TOP_DIR}/../tarballs/${BINUTILS_TAR}"
`case "${BINUTILS_VER}" in
2.23.*)
     echo "CT_BINUTILS_V_2_23_2=y"
     ;;
2.24)
    echo "CT_BINUTILS_V_$(echo ${BINUTILS_VER} | tr '.' '_')=y"
    ;;
2.25.1)
    echo "CT_BINUTILS_V_$(echo ${BINUTILS_VER} | tr '.' '_')=y"
    ;;
2.27)
    echo "CT_BINUTILS_V_$(echo ${BINUTILS_VER} | tr '.' '_')=y"
    ;;
2.25)
    echo "CT_BINUTILS_V_2_25_1=y"
    ;;
2.28)
    echo "CT_BINUTILS_V_2_28_1=y"
    ;;
*)
    ;;
esac`

# C-library
CT_LIBC_GLIBC=y
CT_GLIBC_SRC_CUSTOM=y
CT_GLIBC_CUSTOM_LOCATION="\${CT_TOP_DIR}/../tarballs/${GLIBC_TAR}"
CT_GLIBC_V_2_17=y

# C compiler
CT_GCC_SRC_CUSTOM=y
CT_GCC_CUSTOM_LOCATION="\${CT_TOP_DIR}/../tarballs/${GCC_TAR}"
`case "${GCC_VER}" in
7.*)
    echo "CT_GCC_V_7_3_0=y"
    ;;
6.*)
    echo "CT_GCC_V_6_4_0=y"
    ;;
5.*)
    echo "CT_GCC_V_5_5_0=y"
    ;;
4.9.*)
    echo "CT_GCC_V_4_9_4=y"
    ;;
4.8.*)
    echo "CT_GCC_V_4_8_5=y"
    ;;
*)
    ;;
esac`

# Additional supported languages:
CT_CC_LANG_CXX=y

# Companion libraries
`if [ ! -z "${CLOOG_TAR}" ]; then
    echo "CT_CLOOG_SRC_CUSTOM=y"
    echo "CT_CLOOG_CUSTOM_LOCATION=\"\\${CT_TOP_DIR}/../tarballs/${CLOOG_TAR}\""
    case ${CLOOG_VER} in
    0.18.0)
        echo "CT_CLOOG_V_0_18_1=y"
        ;;
    *)
        ;;
    esac
fi`
CT_GETTEXT_SRC_CUSTOM=y
CT_GETTEXT_CUSTOM_LOCATION="\${CT_TOP_DIR}/../tarballs/${GETTEXT_TAR}"
CT_GETTEXT_V_0_19_8_1=y
CT_GMP_SRC_CUSTOM=y
CT_GMP_CUSTOM_LOCATION="\${CT_TOP_DIR}/../tarballs/${GMP_TAR}"
CT_GMP_V_6_0_0A=y
CT_ISL_SRC_CUSTOM=y
CT_ISL_CUSTOM_LOCATION="\${CT_TOP_DIR}/../tarballs/${ISL_TAR}"
`case ${ISL_VER} in
0.19)
    echo "CT_ISL_V_0_19=y"
    ;;
0.18)
    echo "CT_ISL_V_0_19=y"
    ;;
0.17)
    echo "CT_ISL_V_0_17=y"
    ;;
0.16.1)
    echo "CT_ISL_V_0_16_1=y"
    ;;
*)
    echo "CT_ISL_V_0_15=y"
esac`
CT_MPC_SRC_CUSTOM=y
CT_MPC_CUSTOM_LOCATION="\${CT_TOP_DIR}/../tarballs/${MPC_TAR}"
CT_MPC_V_1_0_3=y
CT_MPFR_SRC_CUSTOM=y
CT_MPFR_CUSTOM_LOCATION="\${CT_TOP_DIR}/../tarballs/${MPFR_TAR}"
CT_MPFR_V_3_0_1=y
CT_NCURSES_SRC_CUSTOM=y
CT_NCURSES_CUSTOM_LOCATION="\${CT_TOP_DIR}/../tarballs/${NCURSES_TAR}"
CT_NCURSES_VERY_OLD=y
EOF

# apply settings created above
./ct-ng defconfig

echo "Run ./ct-ng menuconfig to customize your build target, linux kernel and toolchain alias, then run ./ct-ng build."
popd
