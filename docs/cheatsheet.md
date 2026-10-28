# Bug Bounty Cheat Sheet

Flags I use most for each tool. Replace `target.com` / `URL` with your target.

> Tools run through a launcher (`linkfinder`, `subdomainizer`, `xssfuzz`, `sqlidetector`, `ssrfmap`, `upload_bypass`) run from their own folder, so give them full file paths: `$PWD/file.txt`.

- **Subdomains:** [subfinder](#subfinder) · [sublist3r](#sublist3r) · [amass](#amass) · [assetfinder](#assetfinder) · [shuffledns](#shuffledns) · [dnsx](#dnsx) · [github-subdomains](#github-subdomains) · [revwhoix](#revwhoix)
- **Probing and Ports:** [httpx](#httpx) · [naabu](#naabu)
- **URLs and Crawling:** [katana](#katana) · [gospider](#gospider) · [gau](#gau) · [waybackurls](#waybackurls) · [github-endpoints](#github-endpoints) · [gf](#gf)
- **JavaScript and Secrets:** [linkfinder](#linkfinder) · [subdomainizer](#subdomainizer) · [mantra](#mantra) · [trufflehog](#trufflehog)
- **Content Discovery:** [ffuf](#ffuf) · [cewl](#cewl) · [snallygaster](#snallygaster)
- **Exposed .git:** [git-dumper](#git-dumper) · [GitTools](#GitTools)
- **Parameters:** [arjun](#arjun)
- **Vulnerability Scanning:** [nuclei](#nuclei)
- **XSS:** [dalfox](#dalfox) · [xssfuzz](#xssfuzz)
- **Injection:** [sqlidetector](#sqlidetector) · [commix](#commix) · [ssrfmap](#ssrfmap) · [upload_bypass](#upload_bypass)
- **403 / 401 Bypass:** [forbidden](#forbidden) · [nomore403](#nomore403)
- **Cache and Smuggling:** [Web-Cache-Vulnerability-Scanner](#Web-Cache-Vulnerability-Scanner) · [smugglex](#smugglex)

---

# Subdomains

## subfinder

Passive subdomain enumeration.

```shell
subfinder -d target.com                   # basic enumeration
subfinder -d target.com -o subs.txt       # save to file
subfinder -dL domains.txt                 # list of domains
subfinder -d target.com -all              # use all sources
subfinder -d target.com -recursive        # recursive enumeration
subfinder -d target.com -silent           # output only, for piping
subfinder -d target.com -oJ -o out.json   # JSON lines output
subfinder -ls                             # list sources
```

## sublist3r

Subdomains from search engines.

```shell
sublist3r -d target.com                   # basic enumeration
sublist3r -d target.com -o subs.txt       # save to file
sublist3r -d target.com -b                # enable bruteforce
sublist3r -d target.com -e google,bing    # specific engines
sublist3r -d target.com -p 80,443         # check open ports
sublist3r -d target.com -t 20 -v          # threads + live results
```

## amass

Deep subdomain enumeration.

```shell
amass enum -d target.com                      # passive enumeration
amass enum -active -d target.com              # active (zone transfers, certs)
amass enum -brute -d target.com               # bruteforce with default list
amass enum -brute -w words.txt -d target.com  # bruteforce with custom list
amass enum -df domains.txt                    # list of domains
amass enum -timeout 30 -d target.com          # stop after 30 minutes
amass subs -names -d target.com               # print found names from DB
```

## assetfinder

Quick subdomain finder.

```shell
assetfinder target.com                     # domains + related
assetfinder --subs-only target.com         # subdomains only
cat domains.txt | assetfinder --subs-only  # list of domains
```

## shuffledns

Bruteforce and resolve subdomains with massdns.

```shell
shuffledns -d target.com -w words.txt -r ~/wordlists/resolvers.txt -mode bruteforce  # bruteforce
shuffledns -d target.com -list subs.txt -r ~/wordlists/resolvers.txt -mode resolve  # resolve a list
shuffledns ... -o resolved.txt                                # save to file
shuffledns ... -sw                                            # strict wildcard filtering
shuffledns ... -silent                                        # output only
```

## dnsx

Resolve and query DNS records.

```shell
dnsx -l subs.txt -silent                       # keep only resolving hosts
dnsx -l subs.txt -a -resp                      # show A records
dnsx -l subs.txt -cname -resp                  # show CNAMEs (takeover hunting)
dnsx -l subs.txt -r ~/wordlists/resolvers.txt  # custom resolvers
dnsx -d target.com -w words.txt                # bruteforce subdomains
dnsx -l subs.txt -o resolved.txt               # save to file
```

## github-subdomains

Subdomains leaked in GitHub code. Needs `GITHUB_TOKEN`.

```shell
github-subdomains -d target.com                 # search GitHub
github-subdomains -d target.com -o gh-subs.txt  # save to file
github-subdomains -d target.com -q              # quick mode
github-subdomains -d target.com -e              # extended (xtarget.com)
github-subdomains -d target.com -t TOKEN        # pass token directly
```

## revwhoix

Reverse WHOIS: other domains owned by the same org. Needs a WhoisXML API key in `~/.config/whoisxml.conf`.

```shell
revwhoix -k "Target Inc"                  # search by company name
revwhoix -k "admin@target.com"            # search by email
```

---

# Probing and Ports

## httpx

Find live web servers.

```shell
cat subs.txt | httpx -silent              # live hosts only
httpx -l subs.txt -o live.txt             # save to file
httpx -l subs.txt -sc -title -td          # status, title, tech
httpx -l subs.txt -ip -cl                 # IP + content length
httpx -l subs.txt -mc 200                 # match status 200
httpx -l subs.txt -p 80,443,8080,8443     # custom ports
httpx -l subs.txt -fr                     # follow redirects
httpx -u https://target.com -sc -title    # single URL
```

## naabu

Fast port scanner.

```shell
naabu -host target.com                       # top 100 ports
naabu -list subs.txt -top-ports 1000         # top 1000 ports
naabu -host target.com -p -                  # all 65535 ports
naabu -host target.com -p 80,443,8080        # specific ports
naabu -list subs.txt -ec                     # skip CDN IPs
naabu -host target.com -rate 500             # packets per second
naabu -host target.com -nmap-cli 'nmap -sV'  # pipe to nmap
naabu -list subs.txt -silent -o ports.txt    # save to file
```

---

# URLs and Crawling

## katana

Fast web crawler.

```shell
katana -u https://target.com                  # basic crawl
katana -list live.txt -o urls.txt             # list of hosts
katana -u https://target.com -d 5             # crawl depth
katana -u https://target.com -jc              # parse JS for endpoints
katana -u https://target.com -kf all          # robots.txt + sitemap.xml
katana -u https://target.com -headless        # headless browser
katana -u https://target.com -ef png,jpg,css  # skip extensions
katana -u https://target.com -f qurl          # only URLs with params
```

## gospider

Web crawler with 3rd-party sources.

```shell
gospider -s https://target.com                     # crawl one site
gospider -S live.txt -o out/                       # list of sites
gospider -s https://target.com -d 3 -c 10          # depth + concurrency
gospider -s https://target.com --js                # find links in JS
gospider -s https://target.com --sitemap --robots  # sitemap + robots
gospider -s https://target.com -a -w -r            # include 3rd-party URLs
gospider -s https://target.com --cookie "s=abc"    # authenticated crawl
gospider -s https://target.com -q                  # URLs only
```

## gau

Historical URLs (Wayback, Common Crawl, OTX, URLScan).

```shell
gau target.com                            # all known URLs
gau --subs target.com                     # include subdomains
gau target.com --o urls.txt               # save to file
gau target.com --blacklist png,jpg,css    # skip extensions
gau target.com --providers wayback,otx    # specific sources
gau target.com --mc 200                   # only status 200
cat domains.txt | gau --threads 5         # list of domains
```

## waybackurls

URLs from the Wayback Machine.

```shell
echo target.com | waybackurls             # all archived URLs
echo target.com | waybackurls -no-subs    # exclude subdomains
echo target.com | waybackurls -dates      # show capture dates
cat domains.txt | waybackurls > urls.txt  # list of domains
```

## github-endpoints

Endpoints for a domain leaked in GitHub code. Needs `GITHUB_TOKEN`.

```shell
github-endpoints -d target.com            # search GitHub
github-endpoints -d target.com -o ep.txt  # save to file
github-endpoints -d target.com -r         # include relative URLs
github-endpoints -d target.com -all       # include other domains
```

## gf

Grep URLs for likely-vulnerable parameters.

```shell
gf -list                                  # list patterns
cat urls.txt | gf xss                     # XSS candidates
cat urls.txt | gf sqli                    # SQLi candidates
cat urls.txt | gf ssrf                    # SSRF candidates
cat urls.txt | gf redirect                # open redirect candidates
cat urls.txt | gf lfi                     # LFI candidates
cat urls.txt | gf idor                    # IDOR candidates
```

---

# JavaScript and Secrets

## linkfinder

Find endpoints in JavaScript files.

```shell
linkfinder -i https://target.com/app.js -o cli              # one JS file
linkfinder -i https://target.com -d -o cli                  # all JS on a page
linkfinder -i https://target.com/app.js -r '^/api/' -o cli  # filter with regex
linkfinder -i https://target.com -d -c "s=abc" -o cli       # with cookies
linkfinder -i $PWD/burp.xml -b -o cli                       # Burp export
```

## subdomainizer

Subdomains, cloud URLs and secrets from JS.

```shell
subdomainizer -u https://target.com                        # one URL
subdomainizer -l $PWD/live.txt                             # list of URLs
subdomainizer -u https://target.com -o $PWD/subs.txt       # save subdomains
subdomainizer -u https://target.com -sop $PWD/secrets.txt  # save secrets
subdomainizer -u https://target.com -cop $PWD/cloud.txt    # save cloud URLs
subdomainizer -u https://target.com -san all               # subdomains from TLS certs
subdomainizer -u https://target.com -g -gt TOKEN           # also search GitHub
```

## mantra

Find API keys in JS and HTML.

```shell
cat js-urls.txt | mantra                  # scan URLs
cat js-urls.txt | mantra -d               # detailed output
cat js-urls.txt | mantra -s               # silent
cat js-urls.txt | mantra -t 100           # threads
cat js-urls.txt | mantra -c "s=abc"       # with cookies
```

## trufflehog

Find secrets in git repos, orgs and files.

```shell
trufflehog git https://github.com/org/repo  # scan a repo
trufflehog github --org=targetorg           # scan a GitHub org
trufflehog git file://./loot                # scan a dumped .git
trufflehog filesystem ./folder              # scan local files
trufflehog ... --results=verified           # verified secrets only
trufflehog ... --json                       # JSON output
```

---

# Content Discovery

## ffuf

Fuzz directories, files, params and vhosts.

```shell
ffuf -u https://target.com/FUZZ -w words.txt                  # directory fuzzing
ffuf -u https://target.com/FUZZ -w words.txt -e .php,.bak     # add extensions
ffuf ... -mc 200,301,403                                      # match status codes
ffuf ... -fc 404                                              # filter status code
ffuf ... -fs 1234                                             # filter response size
ffuf ... -ac                                                  # auto-filter false positives
ffuf ... -recursion -recursion-depth 2                        # recursive
ffuf -u https://target.com -H "Host: FUZZ.target.com" -w subs.txt  # vhost fuzzing
ffuf -u 'https://target.com/page?FUZZ=1' -w params.txt        # param name fuzzing
ffuf -u https://target.com/login -X POST -d "user=FUZZ" -w users.txt  # POST fuzzing
ffuf ... -rate 50                                             # requests per second
ffuf ... -o out.json -of json                                 # save results
```

## cewl

Build a wordlist from a site's own words.

```shell
cewl https://target.com -w words.txt                 # basic wordlist
cewl https://target.com -d 3 -m 5 -w words.txt       # depth 3, min length 5
cewl https://target.com --lowercase -w words.txt     # lowercase words
cewl https://target.com --with-numbers -w words.txt  # include numbers
cewl https://target.com -e --email_file emails.txt   # collect emails
```

## snallygaster

Find exposed secret files (.git, .env, backups).

```shell
snallygaster target.com                    # scan a host
snallygaster target.com --nowww            # skip www. variant
snallygaster target.com --nohttp           # HTTPS only
snallygaster target.com -t git_dir,dotenv  # specific tests
snallygaster target.com -n                 # noisy tests too
snallygaster target.com -j                 # JSON output
```

---

# Exposed .git

## git-dumper

Download an exposed .git folder.

```shell
git-dumper https://target.com/.git ./loot                     # dump repo
git-dumper https://target.com/.git ./loot -j 20               # faster
git-dumper https://target.com/.git ./loot -H "Cookie: s=abc"  # with header
git-dumper https://target.com/.git ./loot --proxy http://127.0.0.1:8080  # through Burp
```

## GitTools

Find, dump and extract exposed .git repos.

```shell
gittools-finder -i domains.txt -o found.txt      # find exposed .git
gittools-dumper https://target.com/.git/ ./loot  # dump (trailing / required)
gittools-extractor ./loot ./extracted            # rebuild files from commits
```

---

# Parameters

## arjun

Find hidden HTTP parameters.

```shell
arjun -u https://target.com/page                            # GET params
arjun -u https://target.com/page -m POST                    # POST params
arjun -u https://target.com/api -m JSON                     # JSON params
arjun -i urls.txt -o params.json                            # list of URLs
arjun -u https://target.com/page -w words.txt               # custom wordlist
arjun -u https://target.com/page --headers "Cookie: s=abc"  # with headers
arjun -u https://target.com/page --stable                   # slower, avoids rate limits
```

---

# Vulnerability Scanning

## nuclei

Template-based vulnerability scanner.

```shell
nuclei -u https://target.com                     # scan one target
nuclei -l live.txt -o findings.txt               # list of targets
nuclei -l live.txt -s critical,high              # by severity
nuclei -l live.txt -tags cve,exposure            # by tags
nuclei -l live.txt -t http/exposures/            # specific templates
nuclei -l live.txt -as                           # auto-select by detected tech
nuclei -l live.txt -nt                           # only new templates
nuclei -l live.txt -rl 50                        # rate limit
nuclei -u https://target.com -H "Cookie: s=abc"  # with header
nuclei -update-templates                         # update templates
```

---

# XSS

## dalfox

XSS scanner (v3).

```shell
dalfox scan 'https://target.com/?q=1'          # scan one URL
dalfox scan urls.txt                           # list of URLs
cat urls.txt | dalfox scan                     # from pipe
dalfox scan URL -p q                           # test one param
dalfox scan URL -X POST -d "q=1"               # POST request
dalfox scan URL -H "Cookie: s=abc"             # with header
dalfox scan URL -b https://you.oastify.com     # blind XSS callback
dalfox scan URL --proxy http://127.0.0.1:8080  # through Burp
dalfox scan URL -o out.txt -f json             # save as JSON
dalfox scan URL -S                             # results only
```

## xssfuzz

XSS fuzzer for GET parameters.

```shell
xssfuzz -u 'https://target.com/?q=1'      # scan a URL
xssfuzz -u URL -V                         # validate findings
xssfuzz -u URL --param q                  # test one param
xssfuzz -u URL --tag img                  # test one tag
xssfuzz -u URL -p $PWD/payloads.txt       # custom payloads
xssfuzz -u URL -H "Cookie:s=abc"          # with header
xssfuzz -u URL -t 10 --verbose            # threads + detail
xssfuzz -u URL -o $PWD/out.txt            # save results
```

---

# Injection

## sqlidetector

Error-based SQLi detection across many URLs.

```shell
sqlidetector -f $PWD/urls.txt                           # scan URLs with params
sqlidetector -f $PWD/urls.txt -w 50                     # threads
sqlidetector -f $PWD/urls.txt -t 10                     # timeout
sqlidetector -f $PWD/urls.txt -o $PWD/out.txt           # save results
sqlidetector -f $PWD/urls.txt -p http://127.0.0.1:8080  # through Burp
```

## commix

Command injection tester.

```shell
commix -u 'https://target.com/ping?ip=1'         # test GET params
commix -u https://target.com/ping --data="ip=1"  # test POST params
commix -r req.txt                                # Burp request file
commix -u URL -p ip                              # test one param
commix -u URL --cookie="s=abc"                   # with cookie
commix -u URL --level=3                          # more tests
commix -u URL --proxy=http://127.0.0.1:8080      # through Burp
commix -u URL --batch                            # no prompts
```

## ssrfmap

Exploit a known SSRF. Save the request from Burp first.

```shell
ssrfmap -r $PWD/req.txt -p url -m readfiles                   # read local files
ssrfmap -r $PWD/req.txt -p url -m portscan                    # scan internal ports
ssrfmap -r $PWD/req.txt -p url -m readfiles --rfiles /etc/hosts  # read one file
ssrfmap -r $PWD/req.txt -p url -m portscan -v                 # verbose
```

## upload_bypass

Bypass file upload filters. Save the upload request from Burp first.

```shell
upload_bypass -r $PWD/req.txt -s 'uploaded' -E php -d     # safe detection mode
upload_bypass -r $PWD/req.txt -f 'not allowed' -E php -d  # match failure message
upload_bypass -r $PWD/req.txt -S 200 -E php -d            # match status code
upload_bypass ... -D /uploads                             # upload directory
upload_bypass ... -p http://127.0.0.1:8080                # through Burp
upload_bypass -l                                          # list modules
upload_bypass -U                                          # how to save the request file
```

---

# 403 / 401 Bypass

## forbidden

Bypass 403 and 401 responses.

```shell
forbidden -u https://target.com/admin -t methods,headers,paths-ram -f GET  # common 403 bypasses
forbidden -u https://target.com/admin -t auths -f GET         # 401 bypasses
forbidden ... -o results.json                                 # save results
```

## nomore403

Bypass 403 responses.

```shell
nomore403 -u https://target.com/admin -f ~/tools/nomore403/payloads  # basic scan
nomore403 -u $PWD/targets.txt -f ~/tools/nomore403/payloads   # list of URLs
nomore403 ... -x http://127.0.0.1:8080 -v                     # through Burp, verbose
nomore403 ... -k headers,absolute-uri                         # specific techniques
nomore403 ... --jsonl -o findings.jsonl                       # save results
```

---

# Cache and Smuggling

## Web-Cache-Vulnerability-Scanner

Web cache poisoning and deception scanner.

```shell
Web-Cache-Vulnerability-Scanner -u https://target.com         # scan one URL
Web-Cache-Vulnerability-Scanner -u file:urls.txt              # list of URLs
Web-Cache-Vulnerability-Scanner -u URL -sc "s=abc"            # with cookie
Web-Cache-Vulnerability-Scanner -u URL -sh "Referer: x"       # with header
Web-Cache-Vulnerability-Scanner -u URL -up -purl http://127.0.0.1:8080  # through Burp
Web-Cache-Vulnerability-Scanner -u URL -gr -gp ./wcvs/        # HTML/JSON report
Web-Cache-Vulnerability-Scanner -u URL -r 1                   # follow same-domain links
```

## smugglex

HTTP request smuggling scanner.

```shell
smugglex https://target.com                # scan one URL
cat urls.txt | smugglex                    # list of URLs
smugglex URL -c cl-te,te-cl                # specific checks
smugglex URL -x http://127.0.0.1:8080      # through Burp
smugglex URL -V                            # verbose
smugglex URL -f json -o results.json       # save as JSON
smugglex URL --export-payloads ./payloads  # save working payloads
smugglex --raw-request req.txt             # use a Burp request
cat urls.txt | smugglex -1                 # stop at first hit
```
