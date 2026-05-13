#!/usr/bin/env bash
# =============================================================================
# entrypoint.sh — Ubuntu GitHub Actions Runner container entrypoint
# =============================================================================
set -euo pipefail

# ── Print banner ─────────────────────────────────────────────────────────────
cat <<'BANNER'
 ╔══════════════════════════════════════════════════════════════════╗
 ║         Ubuntu GitHub Actions Runner — Container Image          ║
 ║         Toolchain parity with GitHub-hosted ubuntu-* runners    ║
 ╚══════════════════════════════════════════════════════════════════╝
BANNER

echo "  OS     : $(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')"
echo "  Kernel : $(uname -r)"
echo "  Arch   : $(uname -m)"
echo

# ── Tool version summary ──────────────────────────────────────────────────────
_ver() { command -v "$1" &>/dev/null && "$@" 2>&1 | head -1 || echo "(not found)"; }

echo "  ── Language Runtimes ──────────────────────────────────────────────"
echo "  Bash    : $( bash   --version 2>&1 | head -1 )"
echo "  Python  : $( python3 --version 2>&1 )"
echo "  Node    : $( node   --version 2>&1 )"
echo "  npm     : $( npm    --version 2>&1 )"
echo "  Go      : $( go     version   2>&1 )"
echo "  Rust    : $( rustc  --version  2>&1 )"
echo "  Java    : $( java   --version  2>&1 | head -1 )"
echo
echo "  ── DevOps & Cloud Tools ───────────────────────────────────────────"
echo "  Docker  : $( docker  --version  2>&1 )"
echo "  kubectl : $( kubectl version --client --short 2>&1 | head -1 )"
echo "  Helm    : $( helm    version --short 2>&1 )"
echo "  Terraform:$( terraform version 2>&1 | head -1 )"
echo "  AWS CLI : $( aws     --version  2>&1 )"
echo "  Azure   : $( az      --version  2>&1 | head -1 )"
echo "  GCloud  : $( gcloud  --version  2>&1 | head -1 )"
echo "  gh      : $( gh      --version  2>&1 | head -1 )"
echo "  yq      : $( yq      --version  2>&1 )"
echo "  jq      : $( jq      --version  2>&1 )"
echo

# ── Execute CMD / passed command ──────────────────────────────────────────────
exec "$@"
