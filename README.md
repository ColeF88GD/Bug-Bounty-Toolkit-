# Bug Bounty Toolkit

My Kali setup for bug bounty and web pentesting: one script to install 37 tools, one command to run full recon, and the workflows and cheat sheets I use on every target.

## Quick start

```shell
git clone https://github.com/ColeF88GD/bug-bounty-toolkit ~/tools/bug-bounty-toolkit
cd ~/tools/bug-bounty-toolkit
bash scripts/install-bugbounty-tools.sh        # 15–30 min, safe to re-run
ln -sf "$PWD/scripts/recon.sh" ~/.local/bin/recon
source ~/.zshrc

recon -d target.com -x out-of-scope.txt
```

Then follow [WORKFLOW.md](WORKFLOW.md).

## What's inside

| File | What it is |
|---|---|
| [WORKFLOW.md](WORKFLOW.md) | **Master workflow:** setup → scope → recon → triage → fuzzing → testing → report |
| [scripts/install-bugbounty-tools.sh](scripts/install-bugbounty-tools.sh) | Installs every tool below on Kali (Go, Rust, pipx, venvs) |
| [scripts/recon.sh](scripts/recon.sh) | Automated recon pipeline with scope filtering and resume |
| [docs/cheatsheet.md](docs/cheatsheet.md) | Most-used flags for every tool |
| [docs/recon-workflow.md](docs/recon-workflow.md) | Recon steps by hand (what `recon.sh` automates) |
| [docs/fuzzing-workflow.md](docs/fuzzing-workflow.md) | Content discovery and fuzzing with ffuf |
| [templates/out-of-scope.example.txt](templates/out-of-scope.example.txt) | Example scope-exclusion file for `recon.sh -x` |
| [templates/report-template.md](templates/report-template.md) | Bug report template |

## recon.sh

```
recon -d DOMAIN [options]

  -d DOMAIN    target root domain (required)
  -x FILE      out-of-scope list: one host or regex per line
  -o DIR       output folder        (default: ~/bugbounty/targets/DOMAIN)
  -r RATE      requests/sec limit   (default: 50)
  -a           also run amass
  -P           skip port scan
  -N           skip nuclei
  -f           force: redo steps that already have output
```

Pipeline: subfinder, assetfinder, github-subdomains, amass → dnsx → httpx, naabu → katana, gau, waybackurls → mantra, linkfinder → gf → nuclei, nomore403, snallygaster. Ends with a `summary.txt` of what to look at first. Missing tools are skipped, not fatal.

## Tools

| Category | Tools |
|---|---|
| Subdomains | subfinder, sublist3r, amass, assetfinder, shuffledns, dnsx, github-subdomains, revwhoix |
| Probing / ports | httpx, naabu |
| URLs / crawling | katana, gospider, gau, waybackurls, github-endpoints, gf |
| JS / secrets | linkfinder, SubDomainizer, mantra, trufflehog |
| Content discovery | ffuf, CeWL, snallygaster |
| Exposed .git | git-dumper, GitTools |
| Parameters | arjun |
| Scanning | nuclei |
| XSS | dalfox, xssFuzz |
| Injection | SQLiDetector, commix, SSRFmap, Upload_Bypass |
| 403 bypass | forbidden, nomore403 |
| Cache / smuggling | Web Cache Vulnerability Scanner, smugglex |

Plus SecLists, gf patterns, and a trusted DNS resolver list.

## Requirements

- Kali Linux (tested on 2026.3), run as a normal user with sudo
- ~10 GB free disk for tools and wordlists
- Optional API keys: `GITHUB_TOKEN`, WhoisXML (`~/.config/whoisxml.conf`), subfinder providers

## Disclaimer

For authorized testing only: bug bounty programs you're enrolled in, your own systems, or systems you have written permission to test. Always follow each program's scope and rules. I'm not responsible for misuse.

## Credits

All tools belong to their authors. See each project's GitHub page, linked from [scripts/install-bugbounty-tools.sh](scripts/install-bugbounty-tools.sh).
