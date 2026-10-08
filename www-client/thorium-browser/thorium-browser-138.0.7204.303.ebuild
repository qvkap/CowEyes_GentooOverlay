# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Thorium Browser - Chromium fork with aggressive compiler optimizations (AVX2 build)"
HOMEPAGE="https://thorium.rocks/"
SRC_URI="https://github.com/Alex313031/thorium/releases/download/M${PV}/thorium-browser_${PV}_AVX2.deb -> ${P}-AVX2.deb"

LICENSE="BSD"
SLOT="0"
KEYWORDS="~amd64"
IUSE=""

S="${WORKDIR}"

RESTRICT="strip"

RDEPEND="
	app-misc/ca-certificates
	media-fonts/liberation-fonts
	media-libs/alsa-lib
	x11-libs/cairo
	media-libs/mesa
	x11-libs/pango
	media-libs/vulkan-loader
	net-print/cups
	dev-libs/atk
	dev-libs/nspr
	dev-libs/nss
	app-accessibility/at-spi2-core
	x11-libs/gtk+:3
	x11-libs/libX11
	x11-libs/libXcomposite
	x11-libs/libXdamage
	x11-libs/libXext
	x11-libs/libXfixes
	x11-libs/libXrandr
	x11-libs/libxkbcommon
	x11-misc/xdg-utils
"

src_unpack() {
	cd "${WORKDIR}" || die
	ar x "${DISTDIR}/${A}" || die "ar x failed"
	tar -xf data.tar.xz || die "tar data.tar.xz failed"
	rm -f debian-binary control.tar.* data.tar.*
}

src_install() {
	local d
	for d in opt usr; do
		[[ -d "${S}/${d}" ]] || continue
		cp -a "${S}/${d}" "${D}/" || die
	done
	[[ -e "${D}/usr/bin/thorium-browser" ]] || \
		dosym /opt/chromium.org/thorium/thorium-browser /usr/bin/thorium-browser
}

pkg_postinst() {
	command -v update-desktop-database >/dev/null && update-desktop-database -q \
		"${EPREFIX}/usr/share/applications" 2>/dev/null || true
	command -v update-mime-database >/dev/null && update-mime-database \
		"${EPREFIX}/usr/share/mime" 2>/dev/null || true
}
