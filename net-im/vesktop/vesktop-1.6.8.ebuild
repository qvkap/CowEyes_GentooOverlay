# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
EAPI=8

inherit desktop xdg

DESCRIPTION="All-in-one voice and text chat for gamers with Vencord Preinstalled (built from source)"
HOMEPAGE="https://github.com/Vencord/Vesktop"

if [[ ${PV} == *9999* ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/Vencord/Vesktop.git"
else
	SRC_URI="https://github.com/Vencord/Vesktop/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"
	KEYWORDS="~amd64 ~arm64"
fi

LICENSE="GPL-3+"
SLOT="0"
IUSE="system-electron"

RESTRICT="network-sandbox"

RDEPEND="
	!net-im/vesktop-bin
	system-electron? ( dev-util/electron:43 )
	!system-electron? (
		app-accessibility/at-spi2-core
		dev-libs/expat
		dev-libs/glib:2
		dev-libs/nspr
		dev-libs/nss
		media-libs/alsa-lib
		media-libs/fontconfig
		media-libs/mesa[gbm(+)]
		net-print/cups
		sys-apps/dbus
		x11-libs/cairo
		x11-libs/gtk+:3
		x11-libs/libXcomposite
		x11-libs/libXdamage
		x11-libs/libXext
		x11-libs/libXfixes
		x11-libs/libXrandr
		x11-libs/libdrm
		x11-libs/libxcb
		x11-libs/libxkbcommon
		x11-libs/pango
	)
"
BDEPEND="
	net-libs/nodejs
	sys-apps/coreutils
"

S="${WORKDIR}/Vesktop-${PV}"

src_unpack() {
	if [[ ${PV} == *9999* ]]; then
		git-r3_src_unpack
	else
		default
	fi
}

src_compile() {
	# Ensure pnpm is available, installing to temp dir if needed
	export PNPM_HOME="${T}/.pnpm"
	export PATH="${PNPM_HOME}:${PATH}"
	if ! command -v pnpm >/dev/null 2>&1; then
		einfo "Installing temporary local pnpm..."
		corepack enable --install-directory "${PNPM_HOME}" 2>/dev/null || npm install -g --prefix "${T}" pnpm || die "Failed to setup pnpm"
		export PATH="${T}/bin:${PATH}"
	fi

	einfo "Installing pnpm dependencies..."
	pnpm install --frozen-lockfile=false || die "pnpm install failed"

	einfo "Building Vesktop JavaScript/TypeScript bundle from source..."
	pnpm build || die "Build failed"

	if ! use system-electron; then
		einfo "Packaging standalone application..."
		pnpm package:dir || die "Packaging failed"
	fi
}

src_install() {
	doicon -s 256 "${FILESDIR}/vesktop-bin.svg"
	domenu "${FILESDIR}/vesktop.desktop"

	if use system-electron; then
		insinto /usr/lib/vesktop
		doins -r dist/* package.json
		make_wrapper vesktop "electron /usr/lib/vesktop"
	else
		local destdir="/opt/vesktop"
		local build_dir="dist/linux-unpacked"
		[[ -d "dist/linux-arm64-unpacked" ]] && build_dir="dist/linux-arm64-unpacked"

		exeinto "${destdir}"
		doexe "${build_dir}"/vesktop "${build_dir}"/chrome-sandbox "${build_dir}"/*.so*

		insinto "${destdir}"
		doins "${build_dir}"/*.pak "${build_dir}"/*.bin "${build_dir}"/*.dat
		insopts -m0755
		doins -r "${build_dir}"/locales "${build_dir}"/resources

		fowners root "${destdir}/chrome-sandbox"
		fperms 4711 "${destdir}/chrome-sandbox"

		dosym "${destdir}/vesktop" "/usr/bin/vesktop"
	fi
}
