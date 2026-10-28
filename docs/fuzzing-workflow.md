# Fuzzing Workflow

Run in order. Start small, then go bigger only where something looks interesting. Respect the program's rate limit and add any header they require.

```shell
U=https://target.com
SL=/usr/share/seclists
H="X-Bug-Bounty: yourname"        # use the program's required header, if any
R=20                               # requests per second
mkdir -p ffuf
```

## 1. Baseline

See how the site answers a page that doesn't exist, so you know what to filter.

```shell
curl -sk -o /dev/null -w "%{http_code} %{size_download}\n" $U/doesnotexist123
```

If it returns `200` with the same size every time, filter that size with `-fs`. Otherwise `-ac` (auto-calibrate) usually handles it.

## 2. Quick directory scan

```shell
ffuf -u $U/FUZZ -w $SL/Discovery/Web-Content/common.txt -H "$H" -rate $R -ac -ic -o ffuf/quick.json -of json
```

## 3. Bigger scans

```shell
ffuf -u $U/FUZZ -w $SL/Discovery/Web-Content/raft-medium-directories.txt -H "$H" -rate $R -ac -ic -o ffuf/dirs.json -of json
ffuf -u $U/FUZZ -w $SL/Discovery/Web-Content/raft-medium-files.txt       -H "$H" -rate $R -ac -ic -o ffuf/files.json -of json
```

Add extensions that match the tech (check `live-details.txt` from recon):

```shell
ffuf -u $U/FUZZ -w $SL/Discovery/Web-Content/raft-small-words.txt -e .php,.bak,.old,.zip,.txt -H "$H" -rate $R -ac
```

| Tech | Extensions |
|---|---|
| PHP | `.php,.php.bak,.inc` |
| ASP.NET | `.aspx,.ashx,.asmx,.config` |
| Java | `.jsp,.do,.action` |
| Any | `.bak,.old,.zip,.tar.gz,.sql,.env,.log` |

## 4. Custom wordlist from the target

```shell
cewl $U -d 2 -m 4 --lowercase -w ffuf/cewl.txt
cat ffuf/cewl.txt $SL/Discovery/Web-Content/common.txt | sort -u > ffuf/custom.txt
ffuf -u $U/FUZZ -w ffuf/custom.txt -H "$H" -rate $R -ac
```

## 5. Dig into interesting folders

```shell
ffuf -u $U/admin/FUZZ -w $SL/Discovery/Web-Content/raft-medium-words.txt -H "$H" -rate $R -ac
ffuf -u $U/FUZZ -w $SL/Discovery/Web-Content/common.txt -recursion -recursion-depth 2 -H "$H" -rate $R -ac
```

## 6. API endpoints

```shell
ffuf -u $U/api/FUZZ    -w $SL/Discovery/Web-Content/api/api-endpoints.txt -H "$H" -rate $R -ac
ffuf -u $U/api/v1/FUZZ -w $SL/Discovery/Web-Content/api/objects.txt       -H "$H" -rate $R -ac
ffuf -u $U/api/FUZZ -X POST -H "Content-Type: application/json" -d '{}' -w $SL/Discovery/Web-Content/api/api-endpoints.txt -mc all -fc 404,405 -rate $R
```

## 7. Virtual hosts

Finds sites on the same server that don't have public DNS.

```shell
ffuf -u $U -H "Host: FUZZ.target.com" -w $SL/Discovery/DNS/subdomains-top1million-5000.txt -rate $R -ac
```

## 8. Parameters

```shell
arjun -u $U/page                                    # find hidden params
ffuf -u "$U/page?FUZZ=test" -w $SL/Discovery/Web-Content/burp-parameter-names.txt -rate $R -ac
```

Fuzz values once you have a param:

```shell
seq 1 1000 > ffuf/ids.txt
ffuf -u "$U/api/user?id=FUZZ" -w ffuf/ids.txt -H "$H" -H "Cookie: session=YOURS" -rate $R -ac   # IDOR
ffuf -u "$U/page?file=FUZZ" -w $SL/Fuzzing/LFI/LFI-Jhaddix.txt -rate $R -ac                     # LFI
```

## 9. Handle 403s

```shell
nomore403 -u $U/admin -f ~/tools/nomore403/payloads
forbidden -u $U/admin -t methods,headers,paths-ram -f GET
```

## 10. Many hosts at once

```shell
while read -r u; do
  ffuf -u "$u/FUZZ" -w $SL/Discovery/Web-Content/common.txt -H "$H" -rate $R -ac -s \
       -o "ffuf/$(echo "$u" | sed 's#https\?://##; s#[:/]#_#g').json" -of json
done < live.txt
```

## Send hits to Burp

Only matching results get replayed into Burp's history, ready for Repeater.

```shell
ffuf ... -replay-proxy http://127.0.0.1:8080
```

## Filter cheat sheet

| Flag | Does |
|---|---|
| `-ac` | auto-filter false positives |
| `-mc 200,301,403` | show only these codes |
| `-mc all -fc 404` | show everything except 404 |
| `-fs 1234` | hide responses of this size |
| `-fw 57` | hide responses with this word count |
| `-fl 10` | hide responses with this line count |
| `-fr "not found"` | hide responses matching text |
| `-ic` | ignore comment lines in wordlists |
| `-s` | results only |
| `-maxtime 600` | stop after 10 minutes |
