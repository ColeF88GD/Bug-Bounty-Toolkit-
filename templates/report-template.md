# [Bug type] in [feature] allows [impact]

> Example: *Stored XSS in profile bio allows account takeover via session theft*

**Severity:** Critical / High / Medium / Low  (CVSS: `AV:N/AC:L/PR:N/UI:R/S:U/C:H/I:H/A:N`)
**Asset:** `https://sub.target.com`
**Weakness:** CWE-79 Cross-site Scripting

## Summary

One or two sentences: what the bug is, where it is, and what an attacker can do with it.

## Steps to reproduce

1. Log in as user A at `https://sub.target.com/login`.
2. Go to `...` and enter `...`.
3. Send this request:

```http
POST /api/profile HTTP/2
Host: sub.target.com
Cookie: session=<user A>
Content-Type: application/json

{"bio":"<payload>"}
```

4. Log in as user B and visit `...`.
5. Observe `...`.

## Proof of concept

Response, screenshot, or video. Use only your own test accounts and data.

```http
HTTP/2 200 OK
...
```

## Impact

What an attacker can realistically do: whose data, how much, what actions, any preconditions (login required, user interaction, etc.).

## Remediation

Short, concrete fix: e.g. encode output in the bio field, check object ownership on `/api/user/{id}`.

## Notes

Tested on: YYYY-MM-DD, browser/version. Test accounts used: `a@yourmail`, `b@yourmail`.
