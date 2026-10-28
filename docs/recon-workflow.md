# Recon Workflow

Run in order. Each step feeds the next. Check the program's scope before step 3 and remove anything out of scope.

```shell
T=target.com
mkdir -p ~/bugbounty/targets/$T/gf && cd ~/bugbounty/targets/$T
```

## 1. Subdomains

```shell
subfinder -d $T -all -silent                 > subs-raw.txt
assetfinder --subs-only $T                  >> subs-raw.txt
github-subdomains -d $T -raw -o gh.txt; cat gh.txt >> subs-raw.txt
amass enum -d $T -timeout 20; amass subs -names -d $T >> subs-raw.txt   # optional, slow
sort -u subs-raw.txt -o subs.txt
```

## 2. Resolve

```shell
dnsx -l subs.txt -r ~/wordlists/resolvers.txt -silent       > resolved.txt
dnsx -l resolved.txt -cname -resp -silent                   > cnames.txt   # check for takeovers
```

## 3. Live hosts

```shell
httpx -l resolved.txt -silent                               > live.txt
httpx -l resolved.txt -sc -title -td -silent                > live-details.txt
```

## 4. Ports

```shell
naabu -list resolved.txt -top-ports 1000 -ec -silent        > ports.txt
httpx -l ports.txt -silent                                 >> live.txt     # web apps on odd ports
sort -u live.txt -o live.txt
```

## 5. URLs

```shell
katana -list live.txt -jc -kf all -silent                   > urls-raw.txt
gau --subs $T                                              >> urls-raw.txt
echo $T | waybackurls                                      >> urls-raw.txt
grep -viE '\.(png|jpe?g|gif|svg|css|woff2?|ttf|ico)(\?|$)' urls-raw.txt | sort -u > urls.txt
```

## 6. JavaScript

```shell
grep -iE '\.js(\?|$)' urls.txt | httpx -mc 200 -silent      > js.txt
cat js.txt | mantra -s                                      > js-secrets.txt
while read u; do linkfinder -i "$u" -o cli; done < js.txt | sort -u > js-endpoints.txt
```

## 7. Parameters

```shell
grep '=' urls.txt | sort -u                                 > params.txt
for p in xss sqli ssrf redirect lfi idor; do gf $p < params.txt > gf/$p.txt; done
```

## 8. Quick wins

```shell
nuclei -l live.txt -s critical,high,medium -rl 50 -o nuclei.txt
httpx -l resolved.txt -mc 403 -silent                       > 403.txt
nomore403 -u 403.txt -f ~/tools/nomore403/payloads
while read h; do snallygaster "$h" --nowww; done < resolved.txt > exposed.txt
```

## 9. Hand off to testing

```shell
dalfox scan gf/xss.txt -o dalfox.txt
sqlidetector -f $PWD/gf/sqli.txt -o $PWD/sqli.txt
```

Then work through `live-details.txt`, `js-endpoints.txt` and the `gf/` files manually in Burp.

## Output files

| File | What's in it |
|---|---|
| `subs.txt` | all subdomains found |
| `resolved.txt` | subdomains that resolve |
| `cnames.txt` | CNAMEs (takeover candidates) |
| `live.txt` | live web URLs |
| `live-details.txt` | status, title, tech per host |
| `ports.txt` | open ports |
| `urls.txt` | crawled + historical URLs |
| `js-secrets.txt` | API keys in JS |
| `js-endpoints.txt` | endpoints pulled from JS |
| `gf/*.txt` | URLs grouped by bug type |
| `nuclei.txt` | scanner findings |
| `exposed.txt` | exposed files (.git, .env, backups) |
