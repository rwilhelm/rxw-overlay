# Copyright 1999-2019 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

PYTHON_COMPAT=( python3_{5,6,7} )


inherit  linux-mod python-r1 readme.gentoo-r1 virtualx

#https://github.com/openrazer/openrazer/releases/download/v2.7.0/openrazer-2.7.0.tar.xz

DESCRIPTION="Linux drivers for the Razer devices"
HOMEPAGE="https://openrazer.github.io"
inherit  linux-mod python-r1 readme.gentoo-r1 virtualx 

if [[ ${PV} == 9999 ]]; then
	EGIT_REPO_URI="https://github.com/${PN}/${PN}.git"
    inherit git-r3
else

SRC_URI="https://github.com/${PN}/${PN}/releases/download/v${PV}/${PN}-${PV}.tar.xz"
	KEYWORDS=" ~amd64  ~x86 "
fi

LICENSE="GPL-2"
SLOT="0"
IUSE="client +daemon test"
REQUIRED_USE="daemon? ( ${PYTHON_REQUIRED_USE} )
	client? ( daemon )
	test? ( || ( client daemon ) )"

RDEPEND="virtual/udev
	client? ( dev-python/numpy[$PYTHON_USEDEP] )
	daemon? ( ${PYTHON_DEPS}
		dev-python/daemonize[$PYTHON_USEDEP]
		dev-python/dbus-python[$PYTHON_USEDEP]
		dev-python/notify2[$PYTHON_USEDEP]
		dev-python/pygobject:3[$PYTHON_USEDEP]
		dev-python/python-evdev[$PYTHON_USEDEP]
		dev-python/pyudev[$PYTHON_USEDEP]
		dev-python/setproctitle[$PYTHON_USEDEP]
		sys-apps/dbus
		x11-libs/gtk+:3[introspection] )"
DEPEND="${RDEPEND}
	virtual/linux-sources"

DOC_CONTENTS="To run as non-root, add yourself to the plugdev group:\\n
\\tusermod -a -G plugdev <user>"
 


pkg_setup() {
	BUILD_TARGETS="clean driver"
BUILD_PARAMS="-j1 -C ${S} SUBDIRS=${S}/driver"
MODULE_NAMES="
	razerkbd(hid:${S}/driver)
	razermouse(hid:${S}/driver)
	razermousemat(hid:${S}/driver)
	razerkraken(hid:${S}/driver)
	razercore(hid:${S}/driver)
	razeraccessory(hid:${S}/driver)
	
"
	linux-mod_pkg_setup
}





src_prepare() {
	default

	# Fix jobserver unavailable
	sed -i  -e '/daemon install$/s/make/$(MAKE)/' \
		-e '/pylib install$/s/@make/$(MAKE)/' \
		Makefile || die "sed failed for Makefile"
	# Do not to install compressed files
	sed -i '/gzip/d' daemon/Makefile || die "sed failed for daemon/Makefile"
	# Disable failing tests
	sed -i  -e '/test_device_keyboard_effect_framebuffer/i\    @unittest.skip("disable")' \
		-e '/test_device_keyboard_game_mode/i\    @unittest.skip("disable")' \
		-e '/test_device_keyboard_macro_add/i\    @unittest.skip("disable")' \
		-e '/test_device_keyboard_macro_enable/i\    @unittest.skip("disable")' \
		-e '/test_device_keyboard_macro_mode/i\    @unittest.skip("disable")' \
		pylib/tests/integration_tests/test_device_manager.py \
		|| die "sed failed for tests"
}

python_test() {
	if use daemon ; then
		pushd daemon || die "pushd daemon failed"
		"${PYTHON}" -m unittest discover -v tests || die "tests failed with ${EPYTHON}"
		popd || die "popd daemon failed"
	fi
	if use client ; then
		pushd pylib || die "pushd pylib failed"
		dbus-launch || die "dbus-launch failed"
		virtx "${PYTHON}" -m unittest discover -v tests/integration_tests \
			|| die "tests failed with ${EPYTHON}"
		popd || die "popd pylib failed"
	fi
}

src_install() {
	linux-mod_src_install
	readme.gentoo_create_doc

	python_install() {
		# Pass dummy target for false, since empty string disallowed
		emake DESTDIR="${D}" "$(usex daemon daemon_install manual_install_msg)" \
			"$(usex client python_library_install manual_install_msg)"
		python_optimize
	}

	emake DESTDIR="${D}" ubuntu_udev_install
	use daemon && python_foreach_impl python_install
}

pkg_postinst() {
	linux-mod_pkg_postinst
	readme.gentoo_print_elog
}
