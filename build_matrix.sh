#!/bin/sh -e

# This script executes the matrix loops, exclude tests and cleaning.
# The matrix can be configured with the following environment variables:
: "${MATRIX_CC:=gcc clang}"
: "${MATRIX_CMAKE:=no yes}"
: "${MATRIX_REMOTE:=no yes}"
: "${MATRIX_PROTOCHAIN:=yes no}"
# Set this variable to "yes" before calling this script to disregard all cmake
# warnings in a particular environment (CI or a local working copy).  Set it
# to "yes" in this script or in build.sh when a matrix subset is known to be
# not cmake warning-free because of the version or whatever other factor
# that the scripts can detect both in and out of CI.
: "${LIBPCAP_CMAKE_TAINTED:=no}"
# Set this variable to "yes" before calling this script to disregard all
# warnings in a particular environment (CI or a local working copy).  Set it
# to "yes" in this script or in build.sh when a matrix subset is known to be
# not warning-free because of the OS, the compiler or whatever other factor
# that the scripts can detect both in and out of CI.
: "${LIBPCAP_TAINTED:=no}"
# Some OSes have native make without parallel jobs support and sometimes have
# GNU Make available as "gmake".
: "${MAKE_BIN:=make}"
# Custom path to Valgrind (default: use "valgrind" if available).  Set to
# "false" to avoid using Valgrind on a slow host.
: "${VALGRIND_BIN:=valgrind}"
# It calls the build.sh script which runs one build with setup environment
# variables as set below.

. ./build_common.sh
print_sysinfo
# Install directory prefix
if [ -z "$PREFIX" ]; then
    PREFIX=`mktempdir libpcap_build_matrix`
    echo "PREFIX set to '$PREFIX'"
    export PREFIX
fi
COUNT=0
export LIBPCAP_TAINTED
export LIBPCAP_CMAKE_TAINTED
if "$VALGRIND_BIN" --version >/dev/null 2>&1; then
    VALGRIND_CMD="$VALGRIND_BIN --leak-check=full --error-exitcode=1 --quiet"
    export VALGRIND_CMD
    # With Valgrind filtertest takes significantly longer to complete.
    : "${FILTERTEST_TIMEOUT:=5}"
    export FILTERTEST_TIMEOUT
fi

run_after_echo git show --oneline -s | cat
touch .devel
for CC in $MATRIX_CC; do
    export CC
    discard_cc_cache
    if gcc_is_clang_in_disguise; then
        echo '(skipped)'
        continue
    fi
    for CMAKE in $MATRIX_CMAKE; do
        export CMAKE
        for PROTOCHAIN in $MATRIX_PROTOCHAIN; do
            export PROTOCHAIN
            for REMOTE in $MATRIX_REMOTE; do
                export REMOTE
                COUNT=`increment "$COUNT"`
                echo_magenta "===== SETUP $COUNT: CC=$CC CMAKE=$CMAKE REMOTE=$REMOTE PROTOCHAIN=$PROTOCHAIN =====" >&2
                # Run one build as specified.
                run_after_echo ./build.sh
                echo 'Cleaning...'
                if [ "$CMAKE" = yes ]; then rm -rf build; else "$MAKE_BIN" distclean; fi
                purge_directory "$PREFIX"
                run_after_echo git status -suall
            done
        done
    done
done
run_after_echo rm -rf "$PREFIX"
echo_magenta "Tested setup count: $COUNT" >&2
# vi: set tabstop=4 softtabstop=0 expandtab shiftwidth=4 smarttab autoindent :
