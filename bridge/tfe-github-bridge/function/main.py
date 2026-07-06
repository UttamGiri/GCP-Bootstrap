import hashlib
import hmac
import json
import os
import urllib.error
import urllib.request

import functions_framework

TFE_HOSTNAME = os.environ.get("TFE_HOSTNAME", "app.terraform.io")
GITHUB_REPO = os.environ.get("GITHUB_REPO", "UttamGiri/GCP-Bootstrap")
TFE_TOKEN = os.environ.get("TFE_TOKEN", "")
GITHUB_PAT = os.environ.get("GITHUB_PAT", "")
WEBHOOK_SECRET = os.environ.get("TFE_WEBHOOK_SECRET", "")


def verify_signature(body: bytes, signature_header: str) -> bool:
    if not WEBHOOK_SECRET:
        return True
    if not signature_header:
        return False
    expected = hmac.new(WEBHOOK_SECRET.encode(), body, hashlib.sha512).hexdigest()
    return hmac.compare_digest(expected, signature_header.strip())


def tfe_get_run(run_id: str) -> dict:
    url = f"https://{TFE_HOSTNAME}/api/v2/runs/{run_id}"
    req = urllib.request.Request(
        url,
        headers={
            "Authorization": f"Bearer {TFE_TOKEN}",
            "Content-Type": "application/vnd.api+json",
        },
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read())


def github_dispatch(event_type: str, run_id: str) -> None:
    owner, repo = GITHUB_REPO.split("/", 1)
    url = f"https://api.github.com/repos/{owner}/{repo}/dispatches"
    payload = json.dumps(
        {
            "event_type": event_type,
            "client_payload": {"run_id": run_id},
        }
    ).encode()
    req = urllib.request.Request(
        url,
        data=payload,
        method="POST",
        headers={
            "Authorization": f"Bearer {GITHUB_PAT}",
            "Accept": "application/vnd.github+json",
            "Content-Type": "application/json",
        },
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        if resp.status not in (200, 204):
            raise RuntimeError(f"GitHub dispatch failed: HTTP {resp.status}")


@functions_framework.http
def handle(request):
    if request.method != "POST":
        return ("Method not allowed", 405)

    body_bytes = request.get_data() or b""
    signature = request.headers.get("X-TFE-Notification-Signature", "")

    if WEBHOOK_SECRET and not verify_signature(body_bytes, signature):
        return ("Unauthorized", 401)

    try:
        payload = json.loads(body_bytes or b"{}")
    except json.JSONDecodeError:
        return ("Bad request", 400)

    run_id = payload.get("run_id")
    if not run_id:
        return ("OK", 200)

    notifications = payload.get("notifications") or []
    if notifications and "run:completed" not in notifications:
        return (
            json.dumps({"skipped": True, "reason": "not run:completed", "notifications": notifications}),
            200,
            {"Content-Type": "application/json"},
        )

    if not TFE_TOKEN or not GITHUB_PAT:
        return ("Bridge secrets not configured", 503)

    try:
        run_data = tfe_get_run(run_id)
    except urllib.error.HTTPError as exc:
        return (f"TFE API error: HTTP {exc.code}", 502)
    except Exception as exc:
        return (f"TFE API error: {exc}", 502)

    attrs = run_data.get("data", {}).get("attributes", {})
    status = attrs.get("status")
    is_destroy = attrs.get("is-destroy", False)

    if status not in ("applied", "planned_and_finished"):
        return (
            json.dumps({"skipped": True, "reason": f"run status={status}"}),
            200,
            {"Content-Type": "application/json"},
        )

    event_type = "tfe-workload-destroyed" if is_destroy else "tfe-workload-applied"

    try:
        github_dispatch(event_type, run_id)
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        return (f"GitHub error: HTTP {exc.code} {body}", 502)
    except Exception as exc:
        return (f"GitHub error: {exc}", 502)

    return (
        json.dumps({"ok": True, "event_type": event_type, "run_id": run_id}),
        200,
        {"Content-Type": "application/json"},
    )
