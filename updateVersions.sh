#!/bin/sh

# Fetch the filelist from the CentOS Vault and pare it down to only the packages that relate to building a CentOS source toolchain

curl http://vault.centos.org/filelist.gz | gunzip - | grep -e '^\./7\.' | grep -e '/os/Source/SPackages/' -e '/updates/Source/SPackages' -e 'sclo/Source/rh/devtoolset-' | grep -e 'binutils' -e '/gcc-[0-9]' -e 'devtoolset-[0-9]-gcc' -e '/gettext' -e '/glibc' -e 'gmp' -e 'libmpc-' -e 'mpfr' -e 'ncurses' > files
