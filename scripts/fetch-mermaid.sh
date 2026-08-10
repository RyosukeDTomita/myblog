#!/usr/bin/env bash
# ローカル開発用にmermaidのバンドルをjs/へ取得する。
# js/mermaid.min.jsはgit管理外。nixビルドではflake.nixのfetchurlが同じ役割を担う。
# バージョンを上げるときはflake.nixのmermaidVersion/hashも揃えること。
set -euo pipefail

MERMAID_VERSION="11.16.1"
MERMAID_SHA256="18327bef70d96fb505fe7287d9f6a7362ebf07ff6576ddfaffb1a06f3e1a2954"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dest="${repo_root}/js/mermaid.min.js"
url="https://cdn.jsdelivr.net/npm/mermaid@${MERMAID_VERSION}/dist/mermaid.min.js"

verify() {
  echo "${MERMAID_SHA256}  $1" | sha256sum --check --status
}

if [[ -f "${dest}" ]] && verify "${dest}"; then
  echo "mermaid ${MERMAID_VERSION} is already in place: ${dest}"
  exit 0
fi

echo "downloading mermaid ${MERMAID_VERSION} ..."
tmp="$(mktemp)"
trap 'rm -f "${tmp}"' EXIT
curl -sSfL -o "${tmp}" "${url}"

if ! verify "${tmp}"; then
  echo "checksum mismatch for ${url}" >&2
  echo "expected: ${MERMAID_SHA256}" >&2
  echo "actual:   $(sha256sum "${tmp}" | cut -d' ' -f1)" >&2
  exit 1
fi

mv "${tmp}" "${dest}"
chmod 644 "${dest}" # mktempは600で作るので配信できる権限に戻す
trap - EXIT
echo "saved to ${dest}"
