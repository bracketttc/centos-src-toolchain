# Download and patch CentOS sources

This repository contains scripts to download, patch and tar CentOS sources necessary to build a cross-compile toolchain targeting or mirroring a CentOS 7 system.

Currently, this process does not work. At least, not on my home system which is running Fedora 26.

## Motivation

Some organizations require outside security approval for software. Many of those organizations implicitly or explicitly trust software distributed as part of Red Hat Enterprise Linux. Red Hat also runs CentOS and except for branding and support agreements, the two are essentially the same. Importantly, the CentOS sources are made publicly available.

## Remaining work

Automate configuration of crosstool-ng.
