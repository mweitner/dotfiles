#!/usr/bin/env python3
"""Obtain a Microsoft Graph delegated access token via OAuth 2.0 Device Code flow.

Uses the "Microsoft Graph Command Line Tools" first-party client
(14d82eec-204b-4c2f-b7e8-296a70dab67e).  This client is pre-authorized by
Microsoft for delegated scopes such as Chat.Read — no Liebherr tenant admin
consent is required.

Usage:
  get-graph-token.py [--scope SCOPE] [--tenant TENANT] [--output FILE]

Defaults:
  --scope   Chat.Read offline_access
  --tenant  common
  --output  print to stdout (suitable for piping to a file)

Example:
  python3 get-graph-token.py --output ~/.config/teams-graph.token
  chmod 600 ~/.config/teams-graph.token
"""

import argparse
import json
import sys
import time
from urllib.error import HTTPError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

# Microsoft Graph Command Line Tools — pre-authorized first-party client.
# Using this ID bypasses the tenant admin consent requirement for delegated
# Graph scopes (Chat.Read, Mail.Read, etc.).
CLIENT_ID = "14d82eec-204b-4c2f-b7e8-296a70dab67e"

AUTHORITY_BASE = "https://login.microsoftonline.com"


def _post(url: str, data: dict) -> dict:
    body = urlencode(data).encode()
    req = Request(
        url, data=body, headers={"Content-Type": "application/x-www-form-urlencoded"}
    )
    try:
        with urlopen(req) as resp:
            return json.loads(resp.read())
    except HTTPError as exc:
        payload = exc.read()
        try:
            err = json.loads(payload)
        except Exception:
            err = {"raw": payload.decode(errors="replace")}
        raise RuntimeError(f"HTTP {exc.code}: {err}") from exc


def device_code_flow(tenant: str, scope: str) -> str:
    """Run the device code flow and return the access token."""
    device_url = f"{AUTHORITY_BASE}/{tenant}/oauth2/v2.0/devicecode"
    token_url = f"{AUTHORITY_BASE}/{tenant}/oauth2/v2.0/token"

    # Step 1 — request device code
    dc = _post(device_url, {"client_id": CLIENT_ID, "scope": scope})

    print(dc["message"], file=sys.stderr)
    print("", file=sys.stderr)

    interval = int(dc.get("interval", 5))
    expires_in = int(dc.get("expires_in", 900))
    deadline = time.monotonic() + expires_in

    # Step 2 — poll until authorised or expired
    while time.monotonic() < deadline:
        time.sleep(interval)
        try:
            result = _post(
                token_url,
                {
                    "client_id": CLIENT_ID,
                    "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
                    "device_code": dc["device_code"],
                },
            )
        except RuntimeError as exc:
            msg = str(exc)
            if "authorization_pending" in msg:
                continue
            if "slow_down" in msg:
                interval += 5
                continue
            if "authorization_declined" in msg:
                raise RuntimeError("User declined the authorization request.") from exc
            if "expired_token" in msg:
                raise RuntimeError("Device code expired — rerun the script.") from exc
            raise

        return result["access_token"]

    raise RuntimeError("Device code flow timed out — rerun the script.")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Get a Microsoft Graph delegated access token via Device Code flow."
    )
    parser.add_argument(
        "--scope",
        default="https://graph.microsoft.com/Chat.Read offline_access",
        help="Space-separated OAuth scopes (default: Chat.Read offline_access)",
    )
    parser.add_argument(
        "--tenant",
        default="common",
        help="Azure AD tenant ID or 'common' (default: common)",
    )
    parser.add_argument(
        "--output",
        metavar="FILE",
        help="Write token to FILE instead of stdout",
    )
    args = parser.parse_args()

    print("Starting device code flow ...", file=sys.stderr)
    token = device_code_flow(args.tenant, args.scope)

    if args.output:
        with open(args.output, "w") as fh:
            fh.write(token)
        import os

        os.chmod(args.output, 0o600)
        print(f"Token written to {args.output}", file=sys.stderr)
    else:
        print(token)


if __name__ == "__main__":
    main()
