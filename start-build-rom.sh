#!/bin/bash

echo ""
echo "LineageOS 16.x Treble For X6A Buildbot"
echo "ATTENTION: this script syncs repo on each run"
echo "Executing in 5 seconds - CTRL-C to exit"
echo ""
sleep 5

# Abort early on error
set -eE
trap '(\
echo;\
echo \!\!\! An error happened during script execution;\
echo \!\!\! Please check console output for bad sync,;\
echo \!\!\! failed patch application, etc.;\
echo\
)' ERR

START=`date +%s`
BUILD_DATE="$(date +%Y%m%d)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
cd $BASE_DIR

echo "Syncing repos"
repo sync -c --force-sync --no-clone-bundle --no-tags -j$(nproc --all)
echo ""

echo "Setting up build environment"
cd $BASE_DIR/LineageOS-16.x/
source build/envsetup.sh &> /dev/null
echo ""

echo "Applying PHH patches"
cd $BASE_DIR/LineageOS-16.x/frameworks/base
git am $BASE_DIR/lineage_build_unified/patches/0001-Squashed-revert-of-LOS-FOD-implementation.patch
cd $BASE_DIR/LineageOS-16.x/
rm -f device/*/sepolicy/common/private/genfs_contexts
bash $BASE_DIR/treble_experimentations/apply-patches.sh $BASE_DIR/lineage_patches_unified/patches
echo ""

echo "Applying universal patches"
cd $BASE_DIR/LineageOS-16.x/frameworks/base
git am $BASE_DIR/lineage_build_unified/patches/0001-Disable-vendor-mismatch-warning.patch
git am $BASE_DIR/lineage_build_unified/patches/0001-Keyguard-Show-shortcuts-by-default.patch
git am $BASE_DIR/lineage_build_unified/patches/0001-core-Add-support-for-MicroG.patch
cd $BASE_DIR/LineageOS-16.x/lineage-sdk
git am $BASE_DIR/lineage_build_unified/patches/0001-sdk-Invert-per-app-stretch-to-fullscreen.patch
cd $BASE_DIR/LineageOS-16.x/packages/apps/LineageParts
git am $BASE_DIR/lineage_build_unified/patches/0001-LineageParts-Invert-per-app-stretch-to-fullscreen.patch
cd $BASE_DIR/LineageOS-16.x/vendor/lineage
git am $BASE_DIR/lineage_build_unified/patches/0001-vendor_lineage-Log-privapp-permissions-whitelist-vio.patch
cd ../..
echo ""


echo "Applying GSI-specific patches"
cd $BASE_DIR/LineageOS-16.x/build/make
git am $BASE_DIR/lineage_build_unified/patches/0001-Revert-Enable-dyanmic-image-size-for-GSI.patch
cd $BASE_DIR/LineageOS-16.x/external/tinycompress
git revert fbe2bd5c3d670234c3c92f875986acc148e6d792 --no-edit # tinycompress: Use generated kernel headers
cd $BASE_DIR/LineageOS-16.x/vendor/interfaces
git revert 0611b67d96f7f7f71b12079a1b345022fe7bd323 --no-edit # Include Samsung Q camera provider
cd $BASE_DIR/LineageOS-16.x/vendor/lineage
git am $BASE_DIR/lineage_build_unified/patches/0001-build_soong-Disable-generated_kernel_headers.patch
cd $BASE_DIR/LineageOS-16.x/vendor/qcom/opensource/cryptfs_hw
git revert 6a3fc11bcc95d1abebb60e5d714adf75ece83102 --no-edit # cryptfs_hw: Use generated kernel headers
git am $BASE_DIR/lineage_build_unified/patches/0001-Header-hack-to-compile-for-8974.patch
echo ""

echo "CHECK PATCH STATUS NOW!"
sleep 5
echo ""

export WITHOUT_CHECK_API=true
export WITH_SU=true
mkdir -p $BASE_DIR/build-output/


buildVariant() {
	cd $BASE_DIR/LineageOS-16.x/
	lunch ${1}-userdebug
	make installclean
	make -j$(nproc --all) systemimage
	# SKIP the test
	#make vndk-test-sepolicy
	mv $OUT/system.img $BASE_DIR/build-output/lineage-16.0-$BUILD_DATE-UNOFFICIAL-${1}.img
}

buildVariant xiaomi_x6a

ls $BASE_DIR/build-output | grep 'lineage'

END=`date +%s`
ELAPSEDM=$(($(($END-$START))/60))
ELAPSEDS=$(($(($END-$START))-$ELAPSEDM*60))
echo "Buildbot completed in $ELAPSEDM minutes and $ELAPSEDS seconds"
echo ""
