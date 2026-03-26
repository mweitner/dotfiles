# m4-native 1.4.19 uses an older gnulib snapshot.
# New host compiler defaults can trigger C23 attribute parsing issues.
TARGET_CFLAGS:append = " -std=gnu17"

do_compile:prepend() {
	# Force gnulib nodiscard attribute to GNU form for compatibility with
	# this old m4 snapshot when built by newer host toolchains.
	if [ -f ${B}/lib/config.h ]; then
		sed -i 's/\[\[__nodiscard__\]\]/__attribute__ ((__warn_unused_result__))/g' ${B}/lib/config.h
	fi
}
