#!/bin/bash -e

. ../../include/path.sh

if [ "$1" == "build" ]; then
	true
elif [ "$1" == "clean" ]; then
	rm -rf _build$ndk_suffix
	exit 0
else
	exit 255
fi

mkdir -p _build$ndk_suffix
cd _build$ndk_suffix

cpu=armv7-a
[[ "$ndk_triple" == "aarch64"* ]] && cpu=armv8-a
[[ "$ndk_triple" == "x86_64"* ]] && cpu=generic
[[ "$ndk_triple" == "i686"* ]] && cpu="i686 --disable-asm"

cpuflags=
[[ "$ndk_triple" == "arm"* ]] && cpuflags="$cpuflags -mfpu=neon -mcpu=cortex-a8"

args=(
	--target-os=android --enable-cross-compile
	--cross-prefix=$ndk_triple- --cc=$CC --pkg-config=pkg-config --nm=llvm-nm
	--arch=${ndk_triple%%-*} --cpu=$cpu
	--extra-cflags="-I$prefix_dir/include $cpuflags" --extra-ldflags="-L$prefix_dir/lib"

	--enable-{jni,mediacodec,mbedtls,libdav1d,libxml2} --disable-vulkan
	--disable-static --enable-shared --enable-{gpl,version3}

	# disable unneeded parts to keep build lean
	--disable-{stripping,doc,programs}
	--disable-{muxers,encoders,devices}
	
	# Screenshot & dump-cache support
	--enable-encoder=mjpeg,png
	--enable-muxer=mov,matroska,mpegts

	# High-fidelity audio & video decoders/parsers for 4K HDR & Hi-Res Audio
	--enable-decoder=h264,hevc,vp9,av1,mpeg2video,mpeg4,vc1,flv1,mjpeg,theora,prores
	--enable-decoder=aac,ac3,eac3,truehd,dca,flac,opus,vorbis,mp3,alac,pcm_s16le,pcm_s24le,pcm_s32le,pcm_bluray
	--enable-parser=h264,hevc,vp9,av1,dovi,aac,ac3,eac3,dca,flac,mjpeg,opus
	--enable-bsf=hevc_mp4toannexb,h264_mp4toannexb,null,dca_core,eac3_core,truehd_core,dovi_rpu
)
../configure "${args[@]}"

make -j$cores
make DESTDIR="$prefix_dir" install
