#!/usr/bin/env bash
# =============================================================================
#  Bug bounty / pentest toolkit installer for Kali Linux
#  Run as your normal user (NOT root):   bash install-bugbounty-tools.sh
#  Safe to re-run: already-installed tools are updated, failures are skipped
#  and listed at the end.
# =============================================================================

set -u
TOOLS_DIR="$HOME/tools"          # git-cloned Python tools live here
BIN_DIR="$HOME/.local/bin"       # launchers for those tools go here
WORDLIST_DIR="$HOME/wordlists"
FAILED=()

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info() { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
fail() { echo -e "${RED}[x]${NC} $*"; FAILED+=("$1"); }

if [[ $EUID -eq 0 ]]; then
  echo "Run this as your normal user, not root/sudo. It will ask for sudo when needed."
  exit 1
fi

mkdir -p "$TOOLS_DIR" "$BIN_DIR" "$WORDLIST_DIR" "$HOME/.gf"

# -----------------------------------------------------------------------------
# 1. System packages (dependencies + tools Kali already packages)
# -----------------------------------------------------------------------------
info "Updating apt and installing system packages..."
sudo apt update
sudo apt install -y \
  git curl wget jq unzip build-essential pkg-config \
  golang-go python3 python3-pip python3-venv pipx \
  libpcap-dev massdns \
  amass sublist3r cewl commix arjun seclists \
  || fail "apt packages"

# -----------------------------------------------------------------------------
# 2. PATH setup
#    ~/go/bin goes FIRST so ProjectDiscovery's httpx wins over Kali's
#    unrelated python "httpx" command in /usr/bin.
# -----------------------------------------------------------------------------
SHELL_RC="$HOME/.zshrc"; [[ -n "${BASH_VERSION:-}" && ! -f "$SHELL_RC" ]] && SHELL_RC="$HOME/.bashrc"
if ! grep -q "bugbounty-tools PATH" "$SHELL_RC" 2>/dev/null; then
  cat >> "$SHELL_RC" <<'EOF'

# >>> bugbounty-tools PATH >>>
export GOPATH="$HOME/go"
export PATH="$HOME/go/bin:$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
# <<< bugbounty-tools PATH <<<
EOF
  info "Added Go/Rust/local bin paths to $SHELL_RC"
fi
export GOPATH="$HOME/go"
export PATH="$HOME/go/bin:$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
export GOTOOLCHAIN=auto   # lets Go fetch a newer toolchain if a tool needs one

# -----------------------------------------------------------------------------
# 3. Go tools
# -----------------------------------------------------------------------------
declare -A GO_TOOLS=(
  [subfinder]="github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
  [httpx]="github.com/projectdiscovery/httpx/cmd/httpx@latest"
  [dnsx]="github.com/projectdiscovery/dnsx/cmd/dnsx@latest"
  [shuffledns]="github.com/projectdiscovery/shuffledns/cmd/shuffledns@latest"
  [nuclei]="github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
  [katana]="github.com/projectdiscovery/katana/cmd/katana@latest"
  [naabu]="github.com/projectdiscovery/naabu/v2/cmd/naabu@latest"
  [assetfinder]="github.com/tomnomnom/assetfinder@latest"
  [waybackurls]="github.com/tomnomnom/waybackurls@latest"
  [gf]="github.com/tomnomnom/gf@latest"
  [gospider]="github.com/jaeles-project/gospider@latest"
  [gau]="github.com/lc/gau/v2/cmd/gau@latest"
  [ffuf]="github.com/ffuf/ffuf/v2@latest"
  [mantra]="github.com/brosck/mantra@latest"
  [nomore403]="github.com/devploit/nomore403@latest"
  [Web-Cache-Vulnerability-Scanner]="github.com/Hackmanit/Web-Cache-Vulnerability-Scanner@latest"
  [github-subdomains]="github.com/gwen001/github-subdomains@latest"
  [github-endpoints]="github.com/gwen001/github-endpoints@latest"
)

for name in "${!GO_TOOLS[@]}"; do
  info "go install $name"
  go install -v "${GO_TOOLS[$name]}" >/dev/null 2>&1 || fail "$name (go)"
done

# trufflehog can't be built with `go install` (its go.mod uses replace
# directives), so use the official release installer instead
info "Installing trufflehog (official installer)"
curl -sSfL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh \
  | sh -s -- -b "$BIN_DIR" >/dev/null 2>&1 || fail "trufflehog"

# nomore403 reads its payloads folder from the working dir; keep a copy handy
if [[ ! -d "$TOOLS_DIR/nomore403" ]]; then
  git clone -q --depth 1 https://github.com/devploit/nomore403 "$TOOLS_DIR/nomore403" || true
fi

# -----------------------------------------------------------------------------
# 4. Rust tools (dalfox was rewritten in Rust; smugglex is Rust)
# -----------------------------------------------------------------------------
if ! command -v cargo >/dev/null 2>&1; then
  info "Installing Rust (rustup)..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path \
    || fail "rustup"
  # shellcheck disable=SC1091
  source "$HOME/.cargo/env" 2>/dev/null || true
fi
for crate in dalfox smugglex; do
  info "cargo install $crate (this one takes a few minutes)"
  cargo install --locked "$crate" >/dev/null 2>&1 \
    || cargo install "$crate" >/dev/null 2>&1 \
    || fail "$crate (cargo)"
done

# -----------------------------------------------------------------------------
# 5. pipx tools (Kali blocks system-wide pip, so these get isolated envs)
# -----------------------------------------------------------------------------
pipx ensurepath >/dev/null 2>&1
for pkg in snallygaster git-dumper forbidden "git+https://github.com/Sybil-Scan/revwhoix"; do
  info "pipx install $pkg"
  pipx install --force "$pkg" >/dev/null 2>&1 || fail "$pkg (pipx)"
done

# -----------------------------------------------------------------------------
# 6. Git-cloned Python tools, each in its own venv, with a launcher in ~/.local/bin
#    Format:  launcher-name | repo | entry script
# -----------------------------------------------------------------------------
PY_TOOLS=(
  "subdomainizer|https://github.com/nsonaniya2010/SubDomainizer|SubDomainizer.py"
  "linkfinder|https://github.com/GerbenJavado/LinkFinder|linkfinder.py"
  "xssfuzz|https://github.com/Asperis-Security/xssFuzz|xssFuzz.py"
  "sqlidetector|https://github.com/eslam3kl/SQLiDetector|sqlidetector.py"
  "ssrfmap|https://github.com/swisskyrepo/SSRFmap|ssrfmap.py"
  "upload_bypass|https://github.com/sAjibuu/Upload_Bypass|upload_bypass.py"
)

for entry in "${PY_TOOLS[@]}"; do
  IFS='|' read -r launcher repo script <<<"$entry"
  dir="$TOOLS_DIR/$(basename "$repo")"
  info "Setting up $launcher"
  if [[ -d "$dir/.git" ]]; then git -C "$dir" pull -q || true
  else git clone -q --depth 1 "$repo" "$dir" || { fail "$launcher (clone)"; continue; }; fi

  python3 -m venv "$dir/.venv" || { fail "$launcher (venv)"; continue; }
  "$dir/.venv/bin/pip" install -q --upgrade pip setuptools wheel >/dev/null 2>&1
  if [[ -f "$dir/requirements.txt" ]]; then
    "$dir/.venv/bin/pip" install -q -r "$dir/requirements.txt" >/dev/null 2>&1 || fail "$launcher (deps)"
  elif [[ -f "$dir/pyproject.toml" ]]; then
    # install the dependency list from pyproject.toml (e.g. SSRFmap)
    deps=$(python3 -c "import tomllib,sys;print('\n'.join(tomllib.load(open(sys.argv[1],'rb')).get('project',{}).get('dependencies',[])))" "$dir/pyproject.toml")
    [[ -n "$deps" ]] && echo "$deps" | xargs "$dir/.venv/bin/pip" install -q >/dev/null 2>&1 || true
  fi

  cat > "$BIN_DIR/$launcher" <<EOF
#!/usr/bin/env bash
# runs from the tool's folder so it can find its own payload/config files
cd "$dir" && exec "$dir/.venv/bin/python" "$dir/$script" "\$@"
EOF
  chmod +x "$BIN_DIR/$launcher"
done

# -----------------------------------------------------------------------------
# 7. GitTools (Dumper / Extractor / Finder)
# -----------------------------------------------------------------------------
info "Setting up GitTools"
if [[ -d "$TOOLS_DIR/GitTools/.git" ]]; then git -C "$TOOLS_DIR/GitTools" pull -q || true
else git clone -q --depth 1 https://github.com/internetwache/GitTools "$TOOLS_DIR/GitTools" || fail "GitTools"; fi
chmod +x "$TOOLS_DIR"/GitTools/Dumper/gitdumper.sh "$TOOLS_DIR"/GitTools/Extractor/extractor.sh 2>/dev/null
ln -sf "$TOOLS_DIR/GitTools/Dumper/gitdumper.sh"      "$BIN_DIR/gittools-dumper"
ln -sf "$TOOLS_DIR/GitTools/Extractor/extractor.sh"   "$BIN_DIR/gittools-extractor"
cat > "$BIN_DIR/gittools-finder" <<EOF
#!/usr/bin/env bash
exec python3 "$TOOLS_DIR/GitTools/Finder/gitfinder.py" "\$@"
EOF
chmod +x "$BIN_DIR/gittools-finder"

# -----------------------------------------------------------------------------
# 8. gf patterns + DNS resolvers + nuclei templates
# -----------------------------------------------------------------------------
info "Installing gf patterns"
tmp=$(mktemp -d)
git clone -q --depth 1 https://github.com/1ndianl33t/Gf-Patterns "$tmp/gfp" && cp "$tmp"/gfp/*.json "$HOME/.gf/" 2>/dev/null
git clone -q --depth 1 https://github.com/tomnomnom/gf "$tmp/gf"  && cp "$tmp"/gf/examples/*.json "$HOME/.gf/" 2>/dev/null
rm -rf "$tmp"

info "Downloading trusted DNS resolvers (for shuffledns / dnsx)"
curl -sSfL https://raw.githubusercontent.com/trickest/resolvers/main/resolvers-trusted.txt \
  -o "$WORDLIST_DIR/resolvers.txt" || fail "resolvers list"

info "Updating nuclei templates"
command -v nuclei >/dev/null && nuclei -update-templates -silent >/dev/null 2>&1

# -----------------------------------------------------------------------------
# 9. Verify
# -----------------------------------------------------------------------------
echo
info "Checking every tool is on your PATH..."
CHECK=(subfinder sublist3r amass assetfinder httpx gospider subdomainizer cewl
       shuffledns massdns nuclei katana ffuf gau dnsx github-subdomains github-endpoints
       naabu revwhoix waybackurls linkfinder mantra trufflehog snallygaster
       git-dumper gittools-dumper gittools-extractor arjun dalfox xssfuzz sqlidetector
       commix ssrfmap upload_bypass forbidden nomore403
       Web-Cache-Vulnerability-Scanner smugglex gf)
missing=()
for t in "${CHECK[@]}"; do command -v "$t" >/dev/null 2>&1 || missing+=("$t"); done

# make sure httpx is the ProjectDiscovery one, not Kali's python httpx
[[ "$(command -v httpx)" == "$HOME/go/bin/httpx" ]] || warn "httpx is not resolving to ~/go/bin/httpx. Open a new terminal and check again."

echo
if [[ ${#missing[@]} -eq 0 && ${#FAILED[@]} -eq 0 ]]; then
  info "All ${#CHECK[@]} tools installed."
else
  [[ ${#FAILED[@]}  -gt 0 ]] && warn "Steps that failed: ${FAILED[*]}"
  [[ ${#missing[@]} -gt 0 ]] && warn "Not found on PATH: ${missing[*]}"
  warn "Re-running the script usually fixes network hiccups."
fi
echo
info "Open a NEW terminal (or run: source $SHELL_RC) before using the tools."
info "Resolvers list: $WORDLIST_DIR/resolvers.txt   |   gf patterns: ~/.gf   |   cloned tools: $TOOLS_DIR"
