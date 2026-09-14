# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
EAPI=8

DESCRIPTION="The open source AI coding agent"
HOMEPAGE="https://opencode.ai https://github.com/anomalyco/opencode"

if [[ ${PV} == *9999* ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/anomalyco/opencode.git"
else
	SRC_URI="https://github.com/anomalyco/opencode/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"
	KEYWORDS="~amd64"
fi

BUN_VERSION="1.3.14"
BUN_URI="https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}"
NPM_REGISTRY="${NPM_REGISTRY:-https://registry.npmjs.org}"

LICENSE="MIT"
SLOT="0"
IUSE="web-ui +models"

RESTRICT="network-sandbox"

RDEPEND="
	sys-apps/ripgrep
	!dev-util/opencode-bin
"
BDEPEND="
	app-arch/unzip
	net-misc/curl
	!dev-util/opencode-bin
"

S="${WORKDIR}/${P}"

src_unpack() {
	if [[ ${PV} == *9999* ]]; then
		git-r3_src_unpack
	else
		default
	fi

	local arch
	case ${ARCH} in
		amd64) arch="x64" ;;
		arm64) arch="arm64" ;;
		*) die "Unsupported architecture: ${ARCH}" ;;
	esac

	local bun_archive="bun-linux-${arch}.zip"
	local bun_dir="${T}/bun"
	mkdir -p "${bun_dir}" || die

	einfo "Downloading bun ${BUN_VERSION} for building..."
	curl -fL -o "${T}/${bun_archive}" "${BUN_URI}/${bun_archive}" || die "Failed to download bun"

	cd "${bun_dir}" || die
	unzip -q "${T}/${bun_archive}" || die "Failed to extract bun"
	mv "${bun_dir}/bun-linux-${arch}/bun" "${bun_dir}/bun" || die "Failed to move bun binary"
	chmod +x "${bun_dir}/bun" || die
	export PATH="${bun_dir}:${PATH}"

	local bun_bin
	bun_bin="$(command -v bun)" || die "bun not found on PATH after setup"
	[[ "${bun_bin}" == "${bun_dir}/bun" ]] || die "Wrong bun resolved: ${bun_bin}"

	cd "${S}" || die
	git config --global --add safe.directory "${S}" 2>/dev/null || true

	rm -rf packages/console packages/stats packages/enterprise || die
	rm -f bun.lock || die

	if ! use models; then
		cat > "${S}/packages/opencode/models.json" <<- 'MODELS_EOF' || die
			{
			  "opencode": {
			    "id": "opencode",
			    "env": ["OPENCODE_API_KEY"],
			    "npm": "@ai-sdk/openai-compatible",
			    "api": "https://opencode.ai/zen/v1",
			    "name": "OpenCode Zen",
			    "doc": "https://opencode.ai/docs/zen",
			    "models": {
			      "big-pickle": {
			        "id": "big-pickle",
			        "name": "Big Pickle",
			        "family": "big-pickle",
			        "attachment": false,
			        "reasoning": true,
			        "tool_call": true,
			        "interleaved": { "field": "reasoning_content" },
			        "structured_output": true,
			        "temperature": true,
			        "limit": { "context": 200000, "output": 128000 },
			        "cost": { "input": 0, "output": 0, "cache_read": 0, "cache_write": 0 }
			      },
			      "deepseek-v4-flash-free": {
			        "id": "deepseek-v4-flash-free",
			        "name": "DeepSeek V4 Flash Free",
			        "family": "deepseek-flash-free",
			        "attachment": false,
			        "reasoning": true,
			        "tool_call": true,
			        "interleaved": { "field": "reasoning_content" },
			        "structured_output": true,
			        "temperature": true,
			        "knowledge": "2025-05",
			        "modalities": { "input": ["text"], "output": ["text"] },
			        "open_weights": true,
			        "limit": { "context": 1000000, "output": 384000 },
			        "cost": { "input": 0, "output": 0, "cache_read": 0 }
			      },
			      "ring-2.6-1t-free": {
			        "id": "ring-2.6-1t-free",
			        "name": "Ring 2.6 1T Free",
			        "family": "ring-1t-free",
			        "attachment": false,
			        "reasoning": true,
			        "tool_call": true,
			        "interleaved": { "field": "reasoning_content" },
			        "temperature": true,
			        "knowledge": "2025-06",
			        "modalities": { "input": ["text"], "output": ["text"] },
			        "open_weights": true,
			        "limit": { "context": 262000, "output": 66000 },
			        "cost": { "input": 0, "output": 0 }
			      }
			    }
			  }
			}
		MODELS_EOF
		export MODELS_DEV_API_JSON="${S}/packages/opencode/models.json"
	fi

	einfo "Installing npm dependencies from ${NPM_REGISTRY}..."
	bun install --ignore-scripts --registry "${NPM_REGISTRY}" \
		|| die "bun install failed - check network access"

	einfo "Building opencode from source..."
	cd packages/opencode || die

	local build_args=( --single )
	if ! use web-ui; then
		build_args+=( --skip-embed-web-ui )
	fi

	bun run script/build.ts "${build_args[@]}" || die "Build failed"

	local out_bin="${S}/packages/opencode/dist/opencode-linux-${arch}/bin/opencode"
	[ -x "${out_bin}" ] || die "Expected compiled binary not found at ${out_bin}"

	local bare_output
	bare_output="$(printf '' | timeout 5 "${out_bin}" 2>&1 | head -n1)"
	case "${bare_output}" in
		*"fast JavaScript runtime"*)
			die "Compiled binary is a bare bun passthrough, not opencode - build did not bundle the entrypoint correctly"
			;;
	esac

	einfo "Generating JSON schema..."
	bun run script/schema.ts schema.json || die "Schema generation failed"
}

src_configure() { :; }
src_compile() { :; }

src_install() {
	local arch
	case ${ARCH} in
		amd64) arch="x64" ;;
		arm64) arch="arm64" ;;
		*) die "Unsupported architecture: ${ARCH}" ;;
	esac

	local binary_dir="${S}/packages/opencode/dist/opencode-linux-${arch}"
	newbin "${binary_dir}/bin/opencode" "opencode.real"

	dostrip -x /usr/bin/opencode.real

	insinto /usr/share/opencode
	doins "${S}/packages/opencode/schema.json"

	cat > "${ED}/usr/bin/opencode" <<-EOF
		#!/bin/sh
		export OPENCODE_DISABLE_AUTOUPDATE=1
		$(use models || echo "export OPENCODE_DISABLE_MODELS_FETCH=1")
		exec /usr/bin/opencode.real "\$@"
	EOF
	chmod +x "${ED}/usr/bin/opencode" || die
}
