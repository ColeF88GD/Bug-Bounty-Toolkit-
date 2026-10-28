#!/usr/bin/env bash
# =============================================================================
#  recon.sh - automated recon pipeline for bug bounty
#
#  Usage:  recon.sh -d target.com [options]
#
#    -d DOMAIN    target root domain (required)
#    -x FILE      out-of-scope list: one host or regex per line (e.g. ^admin\.)
#    -o DIR       output folder        (default: ~/bugbounty/targets/DOMAIN)
#    -r RATE      requests/sec limit   (default: 50)
#    -a           also run amass       (slow, adds ~20 min)
#    -P           skip port scan
#    -N           skip nuclei
#    -h           help
#
#  Re-running skips steps whose output already exists. Use -f to force.
# =============================================================================

set -uo pipefail

DOMAIN=""; EXCLUDE=""; OUT=""; RATE=50
RUN_AMASS=0; RUN_PORTS=1; RUN_NUCLEI=1; FORCE=0
RESOLVERS="$HOME/wordlists/resolvers.txt"
NOMORE403_PAYLOADS="$HOME/tools/nomore403/payloads"

usage() { sed -n '3,17p' "$0" | sed 's/^# \{0,2\}//'; exit "${1:-0}"; }

while getopts ":d:x:o:r:aPNfh" opt; do
  case $opt in
    d) DOMAIN=$OPTARG ;;
    x) EXCLUDE=$(realpath "$OPTARG") ;;
    o) OUT=$OPTARG ;;
    r) RATE=$OPTARG ;;
    a) RUN_AMASS=1 ;;
    P) RUN_PORTS=0 ;;
    N) RUN_NUCLEI=0 ;;
    f) FORCE=1 ;;
    h) usage 0 ;;
    *) usage 1 ;;
  esac
done
[[ -z "$DOMAIN" ]] && usage 1

OUT=$(realpath -m "${OUT:-$HOME/bugbounty/targets/$DOMAIN}")
mkdir -p "$OUT"/{gf,logs}
cd "$OUT" || exit 1

# ----------------------------------------------------------------------------- helpers
B='\033[1;34m'; G='\033[0;32m'; Y='\033[1;33m'; NC='\033[0m'
START=$(date +%s)
step() { echo -e "\n${B}[$(date +%H:%M:%S)] ==> $*${NC}"; }
ok()   { echo -e "${G}    [+]${NC} $*"; }
warn() { echo -e "${Y}    [!]${NC} $*" >&2; }
have() { command -v "$1" >/dev/null 2>&1 || { warn "$1 not found, skipping"; return 1; }; }
count(){ [[ -s "$1" ]] && wc -l < "$1" | tr -d ' ' || echo 0; }
done_already() { [[ $FORCE -eq 0 && -s "$1" ]] && { ok "$1 exists ($(count "$1") lines), skipping (use -f to redo)"; return 0; }; return 1; }
touchf() { for f in "$@"; do [[ -f "$f" ]] || : > "$f"; done; }

# drop out-of-scope lines from a file, in place
#   apply_scope file        -> file of hostnames
#   apply_scope file url    -> file of URLs (a leading ^ in a pattern matches after https://)
apply_scope() {
  [[ -n "$EXCLUDE" && -s "$1" ]] || return 0
  local before; before=$(count "$1")
  if [[ "${2:-}" == url ]]; then
    grep -viEf <(grep -vE '^\s*(#|$)' "$EXCLUDE" | sed -E 's#^\^#^https?://#; s#\$$#([:/?]|$)#') "$1" > "$1.tmp" || true
  else
    grep -viEf <(grep -vE '^\s*(#|$)' "$EXCLUDE") "$1" > "$1.tmp" || true
  fi
  mv "$1.tmp" "$1"
  ok "scope filter: $before -> $(count "$1") in $1"
}

echo -e "${B}Recon: $DOMAIN${NC}  ->  $OUT"
[[ -n "$EXCLUDE" ]] && echo "Out-of-scope list: $EXCLUDE" || warn "No -x scope file given. Make sure everything under *.$DOMAIN is in scope."
[[ -s "$RESOLVERS" ]] || { warn "Resolvers list missing at $RESOLVERS, dnsx will use defaults"; RESOLVERS=""; }

# ============================================================================= 1. subdomains
step "1. Subdomain enumeration"
if ! done_already subs.txt; then
  : > subs-raw.txt
  have subfinder   && subfinder -d "$DOMAIN" -all -silent 2>>logs/subfinder.log >> subs-raw.txt
  have assetfinder && assetfinder --subs-only "$DOMAIN" 2>>logs/assetfinder.log >> subs-raw.txt
  if [[ -n "${GITHUB_TOKEN:-}" ]] && have github-subdomains; then
    github-subdomains -d "$DOMAIN" -raw -o gh-subs.txt >>logs/github.log 2>&1
    [[ -f gh-subs.txt ]] && cat gh-subs.txt >> subs-raw.txt
  else
    warn "GITHUB_TOKEN not set, skipping github-subdomains"
  fi
  if [[ $RUN_AMASS -eq 1 ]] && have amass; then
    amass enum -d "$DOMAIN" -timeout 20 >>logs/amass.log 2>&1
    amass subs -names -d "$DOMAIN" 2>>logs/amass.log >> subs-raw.txt
  fi
  # keep only real hostnames under the target domain
  tr 'A-Z' 'a-z' < subs-raw.txt | sed 's/^\*\.//' \
    | grep -E "^([a-z0-9_-]+\.)*${DOMAIN//./\\.}$" | sort -u > subs.txt
  apply_scope subs.txt
fi
ok "subdomains: $(count subs.txt)"

# ============================================================================= 2. resolve
step "2. DNS resolution"
if ! done_already resolved.txt && have dnsx; then
  dnsx -l subs.txt ${RESOLVERS:+-r "$RESOLVERS"} -silent 2>>logs/dnsx.log | sort -u > resolved.txt
  dnsx -l resolved.txt ${RESOLVERS:+-r "$RESOLVERS"} -cname -resp -silent 2>>logs/dnsx.log > cnames.txt
fi
touchf resolved.txt cnames.txt
ok "resolved: $(count resolved.txt)   cnames: $(count cnames.txt)"

# ============================================================================= 3. live hosts
step "3. Live web hosts"
if ! done_already live.txt && have httpx; then
  httpx -l resolved.txt -silent -rl "$RATE" 2>>logs/httpx.log | sort -u > live.txt
  httpx -l resolved.txt -sc -title -td -silent -nc -rl "$RATE" 2>>logs/httpx.log > live-details.txt
fi
touchf live.txt live-details.txt
ok "live: $(count live.txt)"

# ============================================================================= 4. ports
if [[ $RUN_PORTS -eq 1 ]]; then
  step "4. Port scan (top 1000)"
  if ! done_already ports.txt && have naabu; then
    naabu -list resolved.txt -top-ports 1000 -ec -rate "$((RATE * 10))" -silent 2>>logs/naabu.log > ports.txt
    touchf ports.txt
    have httpx && httpx -l ports.txt -silent -rl "$RATE" 2>>logs/httpx.log >> live.txt
    sort -u live.txt -o live.txt
  fi
  touchf ports.txt
  ok "open ports: $(count ports.txt)   live (incl. odd ports): $(count live.txt)"
fi

# ============================================================================= 5. urls
step "5. URL collection"
if ! done_already urls.txt; then
  : > urls-raw.txt
  have katana      && katana -list live.txt -jc -kf all -d 3 -rl "$RATE" -silent 2>>logs/katana.log >> urls-raw.txt
  have gau         && gau --subs "$DOMAIN" 2>>logs/gau.log >> urls-raw.txt
  have waybackurls && echo "$DOMAIN" | waybackurls 2>>logs/wayback.log >> urls-raw.txt
  grep -viE '\.(png|jpe?g|gif|svg|webp|css|woff2?|ttf|eot|ico|mp4|mp3|pdf)(\?|$)' urls-raw.txt \
    | sort -u > urls.txt
  apply_scope urls.txt url
fi
touchf urls.txt
ok "urls: $(count urls.txt)"

# ============================================================================= 6. javascript
step "6. JavaScript analysis"
if ! done_already js.txt; then
  grep -iE '\.js(\?|$)' urls.txt | sort -u | { have httpx && httpx -mc 200 -silent -rl "$RATE" 2>>logs/httpx.log || cat; } > js.txt
  touchf js.txt
  if [[ -s js.txt ]]; then
    have mantra && mantra -s < js.txt 2>>logs/mantra.log > js-secrets.txt
    if have linkfinder; then
      while read -r u; do linkfinder -i "$u" -o cli 2>>logs/linkfinder.log; done < js.txt \
        | grep -vE '^\s*$|^Running against' | sort -u > js-endpoints.txt
    fi
  fi
fi
touchf js.txt js-secrets.txt js-endpoints.txt
ok "js files: $(count js.txt)   secrets: $(count js-secrets.txt)   endpoints: $(count js-endpoints.txt)"

# ============================================================================= 7. parameters
step "7. Parameter sorting (gf)"
grep '=' urls.txt | sort -u > params.txt
if have gf; then
  for p in xss sqli ssrf redirect lfi rce idor ssti; do
    gf "$p" < params.txt 2>/dev/null | sort -u > "gf/$p.txt"
  done
fi
ok "urls with params: $(count params.txt)"
for f in gf/*.txt; do [[ -s "$f" ]] && ok "  $(basename "$f" .txt): $(count "$f")"; done

# ============================================================================= 8. quick wins
step "8. Quick wins"
if [[ $RUN_NUCLEI -eq 1 ]] && ! done_already nuclei.txt && have nuclei; then
  nuclei -l live.txt -s critical,high,medium -rl "$RATE" -silent -o nuclei.txt 2>>logs/nuclei.log >/dev/null
fi
touchf nuclei.txt

if ! done_already 403.txt && have httpx; then
  httpx -l resolved.txt -mc 403 -silent -rl "$RATE" 2>>logs/httpx.log > 403.txt
  touchf 403.txt
  if [[ -s 403.txt ]] && have nomore403 && [[ -d "$NOMORE403_PAYLOADS" ]]; then
    nomore403 -u "$OUT/403.txt" -f "$NOMORE403_PAYLOADS" > bypass-403.txt 2>>logs/nomore403.log
  fi
fi
touchf 403.txt bypass-403.txt

if ! done_already exposed.txt && have snallygaster; then
  while read -r h; do snallygaster "$h" --nowww 2>>logs/snallygaster.log; done < resolved.txt > exposed.txt
fi
touchf exposed.txt
ok "nuclei findings: $(count nuclei.txt)   403 hosts: $(count 403.txt)   exposed files: $(count exposed.txt)"

# ============================================================================= summary
MINS=$(( ($(date +%s) - START) / 60 ))
cat > summary.txt <<EOF
Recon summary: $DOMAIN   ($(date '+%Y-%m-%d %H:%M'), ${MINS} min)

subdomains        $(count subs.txt)
resolved          $(count resolved.txt)
live web hosts    $(count live.txt)
open ports        $(count ports.txt 2>/dev/null)
urls              $(count urls.txt)
js files          $(count js.txt)
js secrets        $(count js-secrets.txt)
js endpoints      $(count js-endpoints.txt)
urls w/ params    $(count params.txt)
nuclei findings   $(count nuclei.txt)
403 hosts         $(count 403.txt)
exposed files     $(count exposed.txt)

Look at first:  nuclei.txt, js-secrets.txt, exposed.txt, cnames.txt, live-details.txt

Next (active testing, check program rules first):
  dalfox scan $OUT/gf/xss.txt -o $OUT/dalfox.txt
  sqlidetector -f $OUT/gf/sqli.txt -o $OUT/sqli.txt
EOF

echo; cat summary.txt
echo -e "\n${G}Done in ${MINS} min. Results: $OUT${NC}"
