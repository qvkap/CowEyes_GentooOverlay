# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

QTMIN=6.4.0
inherit cmake java-pkg-2 flag-o-matic optfeature toolchain-funcs xdg git-r3

DESCRIPTION="PineconeMC (ElyPrismLauncher) - custom, open source Minecraft launcher"
HOMEPAGE="https://github.com/ElyPrismLauncher/Launcher"
EGIT_REPO_URI="https://github.com/ElyPrismLauncher/Launcher.git"
EGIT_SUBMODULES=( '-*' '*' )

LICENSE="Apache-2.0 BSD BSD-2 GPL-2+ GPL-3 ISC LGPL-2.1+ LGPL-3+"
SLOT="0"
IUSE="+gamemode lto pch test"

RESTRICT="!test? ( test )"

COMMON_DEPEND="
	app-arch/libarchive:=
	app-text/cmark:=
	dev-cpp/tomlplusplus
	>=dev-qt/qtbase-${QTMIN}:6[concurrent,gui,opengl,network,vulkan,widgets,xml(+)]
	>=dev-qt/qtnetworkauth-${QTMIN}:6
	gamemode? ( games-util/gamemode )
	media-gfx/qrencode:=
	virtual/zlib:=
"
DEPEND="${COMMON_DEPEND}
	media-libs/libglvnd
	<virtual/jdk-26:*
"
RDEPEND="${COMMON_DEPEND}
	>=dev-qt/qtsvg-${QTMIN}:6
	>=virtual/jre-1.8.0:*
	virtual/opengl
"
BDEPEND="
	>=kde-frameworks/extra-cmake-modules-6.0.0:*
	virtual/pkgconfig
"

src_unpack() {
	git-r3_src_unpack
}

src_prepare() {
	cmake_src_prepare

	local java="$(java-config -f)"
	local java_version=${java//[^0-9]/}
	if [[ ${java_version} -ge 20 ]]; then
		elog "Java 20 and up has dropped binary compatibility with java 7."
		elog "${PN} is being compiled with java ${java_version}."
		elog "The sources will be patched to build binary compatible with"
		elog "java 8 instead of java 7."
		if [[ -f "${FILESDIR}/${PN}-11.1.0-openjdk21.patch" ]]; then
			eapply "${FILESDIR}/${PN}-11.1.0-openjdk21.patch"
		fi
	fi
}

src_configure() {
	if use lto; then
		if tc-is-clang; then
			append-flags -flto=thin
		else
			append-flags -flto
		fi
	else
		filter-lto
	fi

	local mycmakeargs=(
		-DCMAKE_INSTALL_PREFIX="/usr"
		-DLauncher_APP_BINARY_NAME="${PN}"
		-DLauncher_BUILD_PLATFORM="Gentoo Linux"
		-DLauncher_QT_VERSION_MAJOR=6
		-DENABLE_LTO=$(usex lto)
		-DLauncher_USE_PCH=$(usex pch)
		-DBUILD_TESTING=$(usex test)
	)

	cmake_src_configure
}

pkg_postinst() {
	xdg_pkg_postinst

	optfeature "built-in MangoHud support (available in GURU overlay)" games-util/mangohud
	optfeature "built-in Feral Gamemode support" games-util/gamemode
}
