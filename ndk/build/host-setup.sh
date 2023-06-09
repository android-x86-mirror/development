#!/bin/sh
#
# Copyright (C) 2009 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#  A shell script used to configure the host-specific parts of the NDK
#  build system. This will create out/host/config-host.make based on
#  your host system and additionnal command-line options.
#

# check that this script is run from the top-level NDK directory
if [ ! -f build/core/ndk-common.sh ] ; then
    echo "Please run this script from the top-level NDK directory as in:"
    echo "   cd \$NDKROOT"
    echo "   build/host-setup.sh"
    exit 1
fi

# include common function and variable definitions
. `dirname $0`/core/ndk-common.sh

OUT_DIR=out
HOST_CONFIG=$OUT_DIR/host/config.mk

## Build configuration file support
## you must define $config_mk before calling this function
##
create_config_mk ()
{
    # create the directory if needed
    local  config_dir
    config_mk=${config_mk:-$HOST_CONFIG}
    config_dir=`dirname $config_mk`
    mkdir -p $config_dir 2> $TMPL
    if [ $? != 0 ] ; then
        echo "Can't create directory for host config file: $config_dir"
        exit 1
    fi

    # re-create the start of the configuration file
    log "Generate   : $config_mk"

    echo "# This file was autogenerated by $PROGNAME. Do not edit !" > $config_mk
}

add_config ()
{
    echo "$1" >> $config_mk
}

# assume $1 points to a GNU Make executable, and extract version number
# to verify its a least what we need
check_gnu_make_version ()
{
    if [ -n "$GNU_MAKE" ] ; then
        return
    fi

    log2 "  looking for GNU Make as '$1'"
    local executable=`which $1`
    if [ -z "$executable" ] ; then
        log2 "    Not available."
        return
    fi

    # I'd love to do the version extraction with awk, but I'm unsure it is
    # part of the default Cygwin install, so don't bring the dependency
    # and rely on dumb tools instead.
    #
    local version major minor
    version=`$executable --version | grep "GNU Make"`
    if [ -z "$version" ] ; then
        log2 "    Not a GNU Make executable."
        return
    fi
    version=`echo $version | sed -e 's/^GNU Make \([0-9\.]*\).*$/\1/g'`
    log2 "    Found version $version"
    major=`echo $version | sed -e 's/\([0-9]*\)\..*/\1/g'`
    minor=`echo $version | sed -e 's/[0-9]*\.\(.*\)/\1/g'`
    if [ "$major" -lt "3" ] ; then
        log2 "    Major version too small ($major.$minor < 3.81)."
        return
    fi
    if [ "$major" -eq "3" -a $minor -lt 80 ] ; then
        log2 "    Minor version too small ($major.$minor < 3.81)."
        return
    fi
    GNU_MAKE=$1
    GNU_MAKE_VERSION=$version
}

# check that $1 points to an awk executable that has a working
# match() function. This really means Nawk or GNU Awk, which should
# be installed on all modern distributions, but hey, you never know...
check_awk ()
{
    if [ -n "$AWK" ] ; then
        return
    fi
    log2 "  looking for nawk/gawk as '$1'"
    local executable=`which $1`
    if [ -z "$executable" ] ; then
        log2 "    Not available."
        return
    fi
    local result
    result=`echo "" | $executable -f build/check-awk.awk`
    if [ "$result" = "Pass" ] ; then
        AWK="$1"
    fi
    log2 "    Check $result"
}

OPTION_HELP=no
OPTION_NO_MAKE_CHECK=no
OPTION_NO_AWK_CHECK=no

for opt do
  optarg=`expr "x$opt" : 'x[^=]*=\(.*\)'`
  case "$opt" in
  --help|-h|-\?) OPTION_HELP=yes
  ;;
  --no-make-check) OPTION_NO_MAKE_CHECK=yes
  ;;
  --no-awk-check) OPTION_NO_AWK_CHECK=yes
  ;;
  --verbose)
    if [ "$VERBOSE" = "yes" ] ; then
        VERBOSE2=yes
    else
        VERBOSE=yes
    fi
  ;;
  *)
    echo "unknown option '$opt', use --help"
    exit 1
  esac
done

if [ $OPTION_HELP = yes ] ; then
    echo "Usage: build/host-setup.sh [options]"
    echo ""
    echo "This script is used to check your host development environment"
    echo "to ensure that the Android NDK will work correctly with it."
    echo ""
    echo "Options: [defaults in brackets after descriptions]"
    echo ""
    echo "  --help            Print this help message"
    echo "  --verbose         Enable verbose mode"
    echo "  --no-make-check   Ignore GNU Make version check"
    echo "  --no-awk-check    Ignore Nawk/Gawk check"
    echo ""
    exit 1
fi


echo "Checking host development environment."
echo "NDK Root   : $ANDROID_NDK_ROOT"

## Check for GNU Make with a proper version number
##
if [ "$OPTION_NO_MAKE_CHECK" = "no" ] ; then
    GNU_MAKE=
    check_gnu_make_version make
    check_gnu_make_version gmake
    if [ -z "$GNU_MAKE" ] ; then
        echo "ERROR: Could not find a valid GNU Make executable."
        echo "       Please ensure GNU Make 3.81 or later is installed."
        echo "       Use the --no-make-check option to ignore this message."
        exit 1
    fi
    echo "GNU Make   : $GNU_MAKE (version $GNU_MAKE_VERSION)"
else
    echo "GNU Make   : Check ignored through user option."
fi

## Check for nawk or gawk, straight awk doesn't have the 'match'
## function we need in the build system.
##
if [ "$OPTION_NO_AWK_CHECK" = "no" ] ; then
    AWK=
    check_awk awk
    check_awk gawk
    check_awk nawk
    if [ -z "$AWK" ] ; then
        echo "ERROR: Could not find a valid Nawk or Gawk executable."
        echo "       Please ensure that either one of them is installed."
        echo "       Use the --no-awk-check option to ignore this message."
        exit 1
    fi
    echo "Awk        : $AWK"
else
    echo "Awk        : Check ignored through user option."
fi

## Check the host platform tag that will be used to locate prebuilt
## toolchain binaries. And create configuration file.
##
force_32bit_binaries
echo "Platform   : $HOST_TAG"

create_config_mk
add_config "HOST_OS       := $HOST_OS"
add_config "HOST_ARCH     := $HOST_ARCH"
add_config "HOST_TAG      := $HOST_TAG"
add_config "HOST_AWK      := $AWK"

## Check that the toolchains we need are installed
## Otherwise, instruct the user to download them from the web site

TOOLCHAINS="arm-eabi-4.2.1 i686-unknown-linux-gnu-4.2.1"

for tc in $TOOLCHAINS; do
    echo "Toolchain  : Checking for $tc prebuilt binaries"
    PREBUILT_BIN=build/prebuilt/$HOST_TAG/$tc/bin
    log2 "Toolchain  : Cross-compiler in <NDK>/$PREBUILT_BIN ?"
    COMPILER_PATTERN=$ANDROID_NDK_ROOT/$PREBUILT_BIN/*-gcc$HOST_EXE 
    COMPILERS=`ls $COMPILER_PATTERN 2> /dev/null`
    if [ -z "$COMPILERS" ] ; then
        echo ""
        echo "ERROR: Toolchain compiler not found"
        echo "It seems you do not have the correct $tc toolchain binaries."
        echo "This may be the result of incorrect unzipping of the NDK archive."
        echo "Please go to the official Android NDK web site and download the"
        echo "appropriate NDK package for your platform ($HOST_TAG)."
        echo "See http://developer.android.com/sdk/index.html"
        echo ""
        echo "ABORTING."
        echo ""
        exit 1
    fi
done

echo ""
echo "Host setup complete. Please read docs/OVERVIEW.TXT if you don't know what to do."
echo ""
