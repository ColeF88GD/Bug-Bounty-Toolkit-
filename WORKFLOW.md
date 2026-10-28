# Master Bug Bounty Workflow

From a fresh Kali install to a submitted report. Each phase feeds the next.

| Phase | What | Time |
|---|---|---|
| [0. Setup](#0-setup) | tools, API keys, Burp | once |
| [1. Scope](#1-scope) | rules, out-of-scope list, headers | 10 min |
| [2. Recon](#2-recon) | subdomains → live hosts → URLs | 20–60 min (automated) |
| [3. Triage](#3-triage) | quick wins from recon output | 30 min |
| [4. Content discovery](#4-content-discovery) | fuzz dirs, files, APIs, vhosts | 1 h+ |
| [5. Vulnerability testing](#5-vulnerability-testing) | XSS, SQLi, SSRF, uploads, 403, cache, smuggling | most of your time |
| [6. Manual testing](#6-manual-testing-in-burp) | auth, IDOR, business logic | most of your time |
| [7. Report](#7-validate-and-report) | confirm, write up, submit | 30 min |

**Related docs:** [cheat sheet](docs/cheatsheet.md) · [recon workflow](docs/recon-workflow.md) · [fuzzing workflow](docs/fuzzing-workflow.md) · [report template](templates/report-template.md)

> Only test targets you have permission to test, stay inside the program's scope, and follow its rate limits. Everything after Phase 1 sends real traffic.

---

## 0. Setup

```shell
sudo apt update && sudo apt full-upgrade -y
git clone https://github.com/ColeF88GD/bug-bounty-toolkit ~/tools/bug-bounty-toolkit
cd ~/tools/bug-bounty-toolkit
bash scripts/install-bugbounty-tools.sh          # installs all tools, 15–30 min
ln -sf "$PWD/scripts/recon.sh" ~/.local/bin/recon
source ~/.zshrc
```

**API keys** (all free tiers):

```shell
echo 'export GITHUB_TOKEN=ghp_...' >> ~/.zshrc                 # github-subdomains/-endpoints (classic token, no scopes)
mkdir -p ~/.config && printf '%s' 'YOUR_KEY' > ~/.config/whoisxml.conf   # revwhoix (whoisxmlapi.com)
nano ~/.config/subfinder/provider-config.yaml                  # subfinder sources (virustotal, securitytrails, ...)
```

**Burp + Firefox:** FoxyProxy → `127.0.0.1:8080`. Browse to `http://burp`, download the CA cert, then import it in Firefox (Settings → Certificates → Authorities, trust for websites).

---

## 1. Scope

Read the program page before running anything.

- [ ] In-scope domains and wildcards
- [ ] Out-of-scope hosts, paths and bug types
- [ ] Rate limit (default here: 50 req/s; lower if they say so)
- [ ] Required header or user agent (e.g. `X-Bug-Bounty: yourname`)
- [ ] Test accounts / sign-up rules
- [ ] Banned tests (DoS, automated scanners, social engineering)

```shell
T=target.com
mkdir -p ~/bugbounty/targets/$T && cd ~/bugbounty/targets/$T
cp ~/tools/bug-bounty-toolkit/templates/out-of-scope.example.txt out-of-scope.txt
nano out-of-scope.txt                       # one host or regex per line
```

---

## 2. Recon

**Automated:** one command runs the full pipeline and writes `summary.txt`.

```shell
recon -d $T -x out-of-scope.txt             # add -a for amass, -r 10 for strict rate limits
```

**Manual:** step-by-step version in [docs/recon-workflow.md](docs/recon-workflow.md).

What it does:

```
subfinder + assetfinder + github-subdomains (+ amass)
        └─> dnsx (resolve, CNAMEs)
              └─> httpx (live hosts)  +  naabu (ports)
                    └─> katana + gau + waybackurls (URLs)
                          ├─> mantra + linkfinder (JS secrets & endpoints)
                          ├─> gf (URLs sorted by bug type)
                          └─> nuclei, nomore403, snallygaster (quick wins)
```

Extra recon worth doing by hand:

```shell
revwhoix -k "Target Inc"                          # other domains owned by the company
github-endpoints -d $T -o github-endpoints.txt    # endpoints leaked in GitHub
trufflehog github --org=targetorg --results=verified   # secrets in their public repos
subdomainizer -l $PWD/live.txt -sop $PWD/subdomainizer-secrets.txt
gospider -S live.txt -d 2 --js -q -o gospider/
```

---

## 3. Triage

Open these first. They're the fastest path to a valid report.

| File | Look for | Next step |
|---|---|---|
| `nuclei.txt` | critical/high hits | verify by hand, never report raw scanner output |
| `js-secrets.txt` | API keys, tokens | test if the key works and what it can access |
| `exposed.txt` | `.git`, `.env`, backups | see below |
| `cnames.txt` | CNAMEs to S3, Heroku, GitHub Pages, Azure | takeover check below |
| `bypass-403.txt` | 200 responses on blocked paths | confirm in Burp |
| `live-details.txt` | odd titles, admin panels, old tech, dev/staging | fuzz in Phase 4 |
| `js-endpoints.txt` | hidden API routes | test in Burp |

**Subdomain takeover:**

```shell
nuclei -l live.txt -tags takeover -rl 50
```

**Exposed .git:**

```shell
httpx -l live.txt -path /.git/HEAD -ms "ref:" -silent       # confirm
git-dumper https://sub.$T/.git ./loot                       # dump
trufflehog git file://./loot --results=verified             # find secrets in history
```

If git-dumper fails, try `gittools-dumper https://sub.$T/.git/ ./loot`, then `gittools-extractor ./loot ./extracted`.

---

## 4. Content Discovery

Full version: [docs/fuzzing-workflow.md](docs/fuzzing-workflow.md).

```shell
U=https://sub.target.com; SL=/usr/share/seclists; H="X-Bug-Bounty: yourname"; R=20
mkdir -p ffuf

# quick, then bigger
ffuf -u $U/FUZZ -w $SL/Discovery/Web-Content/common.txt -H "$H" -rate $R -ac -ic
ffuf -u $U/FUZZ -w $SL/Discovery/Web-Content/raft-medium-directories.txt -H "$H" -rate $R -ac -ic -o ffuf/dirs.json -of json
ffuf -u $U/FUZZ -w $SL/Discovery/Web-Content/raft-medium-files.txt -H "$H" -rate $R -ac -ic -o ffuf/files.json -of json

# target-specific wordlist
cewl $U -d 2 -m 4 --lowercase -w ffuf/cewl.txt

# APIs and vhosts
ffuf -u $U/api/FUZZ -w $SL/Discovery/Web-Content/api/api-endpoints.txt -H "$H" -rate $R -ac
ffuf -u $U -H "Host: FUZZ.target.com" -w $SL/Discovery/DNS/subdomains-top1million-5000.txt -rate $R -ac

# hidden parameters
arjun -u $U/page

# send only hits to Burp
ffuf ... -replay-proxy http://127.0.0.1:8080
```

---

## 5. Vulnerability Testing

Feed tools the `gf/` files from recon. Tools only find candidates; confirm every one by hand in Burp.

### XSS

```shell
dalfox scan $PWD/gf/xss.txt -H "$H" -o dalfox.txt
dalfox scan "$U/search?q=1" -b https://you.oastify.com      # blind XSS callback
xssfuzz -u "$U/search?q=1" -V                               # tag/attribute WAF bypasses
```

### SQL injection

```shell
sqlidetector -f $PWD/gf/sqli.txt -w 20 -o $PWD/sqli.txt     # error-based sweep
sqlmap -u "$U/item?id=1" --batch --level 2 --risk 1          # confirm a single hit
```

### Command injection

```shell
commix -u "$U/ping?ip=1" --batch
commix -r req.txt --batch                                    # from a saved Burp request
```

### SSRF

Look in `gf/ssrf.txt` and any `url=`, `dest=`, `callback=`, webhook, or PDF/image-fetch feature. Confirm with a Burp Collaborator or interactsh URL first, then:

```shell
ssrfmap -r $PWD/req.txt -p url -m readfiles
ssrfmap -r $PWD/req.txt -p url -m portscan
```

### File upload

Save the upload request from Burp (right-click → *Copy to file*):

```shell
upload_bypass -r $PWD/req.txt -s 'uploaded' -E php -d -p http://127.0.0.1:8080
```

Use `-d` (detection mode: harmless files) on live programs. Don't upload web shells unless the program allows it.

### 403 / 401 bypass

```shell
nomore403 -u $U/admin -f ~/tools/nomore403/payloads -x http://127.0.0.1:8080
forbidden -u $U/admin -t methods,headers,paths-ram -f GET
forbidden -u $U/admin -t auths -f GET                        # 401s
```

### Web cache poisoning / deception

```shell
Web-Cache-Vulnerability-Scanner -u $U -sh "$H" -gr -gp ./wcvs/
```

### HTTP request smuggling

```shell
smugglex $U -f json -o smugglex.json
smugglex --raw-request req.txt -x http://127.0.0.1:8080
```

### Open redirect, LFI, IDOR

```shell
cat gf/redirect.txt     # test by hand: ?url=https://evil.com, //evil.com, /\evil.com
ffuf -u "$U/page?file=FUZZ" -w $SL/Fuzzing/LFI/LFI-Jhaddix.txt -rate $R -ac
seq 1 500 > ids.txt && ffuf -u "$U/api/user?id=FUZZ" -w ids.txt -H "Cookie: session=YOURS" -rate $R -ac
```

---

## 6. Manual Testing in Burp

Most valid bounties come from here, not from scanners. Make two accounts (A and B).

- [ ] **IDOR:** replay user A's requests with user B's session. Change every ID in paths, params and JSON bodies.
- [ ] **Auth:** password reset (token reuse, host header poisoning), 2FA skip, session after logout, JWT (`alg: none`, weak secret).
- [ ] **Access control:** call admin endpoints from `js-endpoints.txt` as a normal user. Try other HTTP methods.
- [ ] **Business logic:** negative quantities, coupon reuse, race conditions (Repeater → *Send group in parallel*), skipping steps in multi-step flows.
- [ ] **Input reflection:** every reflected value is a potential XSS. Check headers, JSON, file names.
- [ ] **CORS:** `Origin: https://evil.com` and see if it's reflected with `Access-Control-Allow-Credentials: true`.
- [ ] **API:** old versions (`/v1/` vs `/v2/`), mass assignment (add `"role":"admin"`), GraphQL introspection.

---

## 7. Validate and Report

1. **Reproduce it twice** from a clean session.
2. **Prove impact.** What can an attacker actually do? Use your own test data, never other users' data.
3. **Check for duplicates** in the program's disclosed reports.
4. **Write it up** with [templates/report-template.md](templates/report-template.md). Include: title, severity, steps, PoC request/response, impact, and fix.
5. **Stop testing that bug** once confirmed. Don't escalate further without permission.

Keep notes per target in `~/bugbounty/targets/<target>/notes.md` and screenshots in `screenshots/`.

---

## Re-running

- `recon -d $T -x out-of-scope.txt` again later resumes where it stopped. Add `-f` to redo everything.
- Compare runs to find **new** assets (new subdomains are the least-tested):

```shell
recon -d $T -o ~/bugbounty/targets/$T-$(date +%F) -x out-of-scope.txt
comm -13 <(sort old/subs.txt) <(sort new/subs.txt) > new-subs.txt
```

- Update tools: `bash scripts/install-bugbounty-tools.sh` (safe to re-run) and `nuclei -update-templates`.
