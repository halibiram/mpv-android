#!/bin/bash -e

# go to buildscripts root folder
cd "$( dirname "${BASH_SOURCE[0]}" )/.."

. ./include/depinfo.sh

TARGET_ARCH="${TARGET_ARCH:-arm64}"
ci_tarball="${TARGET_ARCH}-prefix-n${v_ndk}-l${v_lua}-u${v_unibreak}-h${v_harfbuzz}-fr${v_fribidi}-ft${v_freetype}-x${v_libxml2}-fo${v_fontconfig}-m${v_mbedtls}-c${v_curl}-ff${v_ci_ffmpeg}.tgz"

msg() {
	printf '==> %s\n' "$1"
}

fetch_prefix() {
	if [[ "$CACHE_MODE" == folder ]]; then
		local text=
		if [ -f "$CACHE_FOLDER/id_${TARGET_ARCH}.txt" ]; then
			text=$(cat "$CACHE_FOLDER/id_${TARGET_ARCH}.txt")
		else
			echo "Cache seems to be empty for $TARGET_ARCH"
		fi
		printf 'Expecting "%s",\nfound     "%s".\n' "$ci_tarball" "$text"
		if [[ "$text" == "$ci_tarball" ]]; then
			tar -xzf "$CACHE_FOLDER/data_${TARGET_ARCH}.tgz" -C prefix && return 0
		fi
	fi
	return 1
}

build_prefix() {
	msg "Building the prefix ($ci_tarball) for $TARGET_ARCH..."

	msg "Fetching deps"
	IN_CI=1 ./include/download-deps.sh

	msg "Compiling for $TARGET_ARCH"
	./buildall.sh --arch "$TARGET_ARCH" --only-deps mpv

	if [[ "$CACHE_MODE" == folder && -w "$CACHE_FOLDER" ]]; then
		msg "Compressing the prefix for $TARGET_ARCH"
		tar -cvzf "$CACHE_FOLDER/data_${TARGET_ARCH}.tgz" -C prefix .
		echo "$ci_tarball" >"$CACHE_FOLDER/id_${TARGET_ARCH}.txt"
	fi
}

export WGET="wget --progress=bar:force"

if [ "$1" = "export" ]; then
	# export variable with unique cache identifier
	echo "CACHE_IDENTIFIER=$ci_tarball"
	exit 0
elif [ "$1" = "install" ]; then
	# install deps
	if [[ -n "$ANDROID_HOME" && -d "$ANDROID_HOME" ]]; then
		msg "Linking existing SDK"
		mkdir -p sdk
		ln -sv "$ANDROID_HOME" sdk/android-sdk-linux
	fi

	msg "Fetching SDK + NDK"
	IN_CI=1 ./include/download-sdk.sh

	msg "Fetching mpv"
	mkdir -p deps/mpv
	$WGET https://github.com/mpv-player/mpv/archive/master.tar.gz -O master.tgz
	tar -xzf master.tgz -C deps/mpv --strip-components=1
	rm master.tgz

	msg "Trying to fetch existing prefix for $TARGET_ARCH"
	mkdir -p prefix
	fetch_prefix || build_prefix
	exit 0
elif [ "$1" = "build" ]; then
	# run build
	:
else
	exit 1
fi

msg "Building mpv for $TARGET_ARCH"
./buildall.sh --arch "$TARGET_ARCH" -n mpv || {
	# show logfile if configure failed
	[ ! -f deps/mpv/_build_${TARGET_ARCH}/config.h ] && \
		cat deps/mpv/_build_${TARGET_ARCH}/meson-logs/meson-log.txt || :
	exit 1
}

msg "Building mpv-android for $TARGET_ARCH"
./buildall.sh --arch "$TARGET_ARCH" -n

exit 0
