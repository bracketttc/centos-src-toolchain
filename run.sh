#!/bin/sh

REQ_PROGS="basename git rpmbuild sha256sum tar wget"
echo "Checking for required programs..."
for prog in $REQ_PROGS;
do
    if [ ! `which $prog` ]; then
        echo "Script requires $prog"
        exit 1
    fi
done
echo

REPOS="binutils gcc gettext glibc gmp libmpc mpfr ncurses"
echo "Cloning CentOS repos..."
mkdir -p repos
pushd repos > /dev/null
for repo in $REPOS
do
    if [ ! -e $repo ]; then
        git clone https://git.centos.org/r/rpms/$repo.git -b c7
    else
        echo "$repo already exists, assuming git repository on desired branch"
        pushd $repo > /dev/null
        git pull
        popd > /dev/null
    fi
done
popd > /dev/null
echo

echo "Setting up rpmbuild environment"
mkdir -p rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
for repo in repos/*
do
    cp -r $repo/* rpmbuild/.
done
echo

echo "Downloading CentOS blobs..."
for repo in repos/*
do
    baserepo=$(basename $repo)
    cat $repo/.$baserepo.metadata | while read -r line
    do
        HASH=$(echo $line | cut -d' ' -f 1)
        FILENAME=$(echo $line | cut -d' ' -f2-)

	if [ ! -e rpmbuild/$FILENAME ]; then
            wget https://git.centos.org/sources/$baserepo/c7/$HASH -O rpmbuild/$FILENAME
            # wiki.centos.org/Sources says that the filenames correspond to the sha256sum, but
            # that's not accurate
            DOWNLOAD_HASH=$(sha1sum rpmbuild/$FILENAME | cut -d' ' -f 1)
            if [ "$DOWNLOAD_HASH" != "$HASH" ]; then
                echo "Download failed"
            fi
        else
            echo "$FILENAME already exists, skipping..."
        fi
    done
done
echo

echo "Running %prep portion of rpm specs"
pushd rpmbuild > /dev/null
for spec in SPECS/*
do
    rpmbuild --define "_topdir $(pwd)" --nodeps -bp $spec
done
popd > /dev/null
echo

echo "Creating simple tarballs"
mkdir -p tarballs
pushd rpmbuild/BUILD > /dev/null
for d in *
do
    tar zcf ../../tarballs/$d.tar.gz $d
done
pushd gcc* > /dev/null
ISL=$(ls | grep isl)
tar zcf ../../../tarballs/$ISL.tar.gz $ISL
CLOOG=$(ls | grep cloog)
tar zcf ../../../tarballs/$CLOOG.tar.gz $CLOOG
popd
popd
echo

pushd tarballs > /dev/null
if [ ! -e libiconv-1.15.tar.gz ]; then
    wget https://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.15.tar.gz
fi
GCC_VER=$(basename $(ls gcc*) .tar.gz | cut -d '-' -f 2-)
BINUTILS_VER=$(basename $(ls binutils*) .tar.gz | cut -d '-' -f 2-)
GLIBC_VER=$(basename $(ls glibc*) .tar.gz | cut -d '-' -f 2-)
GMP_VER=$(basename $(ls gmp*) .tar.gz | cut -d '-' -f 2-)
MPFR_VER=$(basename $(ls mpfr*) .tar.gz | cut -d '-' -f 2-)
ISL_VER=$(basename $(ls isl*) .tar.gz | cut -d '-' -f 2-)
CLOOG_VER=$(basename $(ls cloog*) .tar.gz | cut -d '-' -f 2-)
MPC_VER=$(basename $(ls mpc*) .tar.gz | cut -d '-' -f 2-)
NCURSES_VER=$(basename $(ls ncurses*) .tar.gz | cut -d '-' -f 2-)
GETTEXT_VER=$(basename $(ls gettext*) .tar.gz | cut -d '-' -f 2-)
popd > /dev/null

if [ ! -e crosstool-ng ]; then
    git clone https://github.com/crosstool-ng/crosstool-ng -b crosstool-ng-1.23.0
fi
pushd crosstool-ng > /dev/null
git apply ../crosstool.patch
cp ../crosstool.config .config
./maintainer/addToolVersion.sh --gcc -s $GCC_VER --binutils $BINUTILS_VER --glibc $GLIBC_VER --gmp $GMP_VER --mpfr $MPFR_VER --isl $ISL_VER --cloog $CLOOG_VER --mpc $MPC_VER --ncurses $NCURSES_VER --gettext $GETTEXT_VER
./bootstrap
./configure --enable-local
make
echo "Run ./ct-ng menuconfig to customize your build target, linux kernel and toolchain alias, then run ./ct-ng build."
popd
