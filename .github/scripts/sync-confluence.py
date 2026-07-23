#!/usr/bin/env python3
"""Sync docs/*.md to Confluence pages using docs/confluence/page-mapping.json."""

from __future__ import annotations

import argparse
import base64
import html
import json
import os
import re
import sys
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen

try:
    import markdown
except ImportError:
    markdown = None


ROOT = Path(__file__).resolve().parents[2]
DOCS_DIR = ROOT / "docs"
MAPPING_FILE = DOCS_DIR / "confluence" / "page-mapping.json"


def load_mapping(env: str) -> dict[str, dict[str, str]]:
    data = json.loads(MAPPING_FILE.read_text(encoding="utf-8"))
    if env not in data:
        raise SystemExit(f"Unknown environment '{env}' in {MAPPING_FILE}")
    return data[env]


def _code_macro(language: str, code: str) -> str:
    lang = html.escape(language or "none")
    return (
        '<ac:structured-macro ac:name="code" ac:schema-version="1">'
        f'<ac:parameter ac:name="language">{lang}</ac:parameter>'
        f"<ac:plain-text-body><![CDATA[{code}]]></ac:plain-text-body>"
        "</ac:structured-macro>"
    )


def markdown_to_storage(md: str) -> str:
    if markdown is None:
        raise SystemExit("markdown package is required: pip install markdown")

    rendered = markdown.markdown(
        md,
        extensions=["tables", "fenced_code", "sane_lists", "nl2br"],
    )

    if not rendered.strip():
        return "<p></p>"

    # Confluence storage format does not render raw <pre><code> reliably.
    def replace_code_block(match: re.Match[str]) -> str:
        classes = match.group(1) or ""
        code = html.unescape(match.group(2))
        language = "none"
        for token in classes.split():
            if token.startswith("language-"):
                language = token.removeprefix("language-")
                break
        return _code_macro(language, code)

    storage = re.sub(
        r'<pre><code(?:\s+class="([^"]*)")?>(.*?)</code></pre>',
        replace_code_block,
        rendered,
        flags=re.DOTALL,
    )

    # Self-close void tags for XHTML storage format.
    for tag in ("br", "hr", "img", "input"):
        storage = re.sub(rf"<{tag}>", rf"<{tag} />", storage)

    return storage


def api_request(
    method: str,
    url: str,
    auth_header: str,
    payload: dict | None = None,
) -> dict:
    body = None
    headers = {
        "Authorization": auth_header,
        "Accept": "application/json",
        "Content-Type": "application/json",
    }
    if payload is not None:
        body = json.dumps(payload).encode("utf-8")

    req = Request(url, data=body, headers=headers, method=method)
    try:
        with urlopen(req) as resp:
            raw = resp.read().decode("utf-8")
            return json.loads(raw) if raw else {}
    except HTTPError as exc:
        err_body = exc.read().decode("utf-8", errors="replace")
        raise SystemExit(f"Confluence API {method} {url} failed ({exc.code}): {err_body}") from exc


def get_page(base_url: str, auth_header: str, page_id: str) -> dict:
    base = base_url.rstrip("/")
    url = f"{base}/wiki/rest/api/content/{page_id}?expand=body.storage,version"
    return api_request("GET", url, auth_header)


def update_page(
    base_url: str,
    auth_header: str,
    page_id: str,
    storage_html: str,
) -> int:
    current = get_page(base_url, auth_header, page_id)
    version = current["version"]["number"]
    title = current["title"]

    payload = {
        "id": page_id,
        "type": "page",
        "title": title,
        "version": {"number": version + 1},
        "body": {
            "storage": {
                "value": storage_html,
                "representation": "storage",
            }
        },
    }
    base = base_url.rstrip("/")
    put_url = f"{base}/wiki/rest/api/content/{page_id}"
    api_request("PUT", put_url, auth_header, payload)

    updated = get_page(base_url, auth_header, page_id)
    saved = updated.get("body", {}).get("storage", {}).get("value", "")
    return len(saved)


def is_placeholder(page_id: str) -> bool:
    return not page_id or page_id.startswith("REPLACE_WITH_")


def sync_file(
    filename: str,
    mapping: dict[str, dict[str, str]],
    base_url: str,
    auth_header: str,
) -> bool:
    if filename not in mapping:
        print(f"skip {filename}: not in page mapping")
        return False

    entry = mapping[filename]
    page_id = entry["page_id"]

    if is_placeholder(page_id):
        print(f"skip {filename}: page_id is still a placeholder ({page_id})")
        return False

    md_path = DOCS_DIR / filename
    if not md_path.exists():
        print(f"skip {filename}: file not found at {md_path}")
        return False

    md = md_path.read_text(encoding="utf-8")
    storage_html = markdown_to_storage(md)
    print(f"syncing {filename} -> page {page_id} ({len(storage_html)} bytes storage HTML)")
    saved_len = update_page(base_url, auth_header, page_id, storage_html)
    print(f"updated {filename} -> page {page_id} (Confluence body now {saved_len} bytes)")
    if saved_len < 20:
        raise SystemExit(
            f"Page {page_id} looks empty after update ({saved_len} bytes). "
            "Check Confluence permissions or storage format."
        )
    return True


def main() -> None:
    parser = argparse.ArgumentParser(description="Sync docs markdown to Confluence")
    parser.add_argument(
        "--env",
        required=True,
        choices=["dev", "prod"],
        help="Which page-mapping section to use",
    )
    parser.add_argument(
        "--files",
        nargs="*",
        help="Markdown filenames to sync (default: all mapped files)",
    )
    args = parser.parse_args()

    base_url = os.environ.get(
        "CONFLUENCE_BASE_URL", "https://vaflt.atlassian.net"
    ).strip()
    email = os.environ.get("CONFLUENCE_EMAIL", "uttamgiri32@vaflt.com").strip()
    token = os.environ.get("CONFLUENCE_API_TOKEN", "").strip()

    if not token:
        raise SystemExit("Set CONFLUENCE_API_TOKEN (Atlassian API token)")

    auth = base64.b64encode(f"{email}:{token}".encode()).decode()
    auth_header = f"Basic {auth}"

    mapping = load_mapping(args.env)
    files = args.files or sorted(mapping.keys())

    updated = 0
    for filename in files:
        if sync_file(filename, mapping, base_url, auth_header):
            updated += 1

    if updated == 0:
        raise SystemExit("No pages were updated (check mapping, placeholders, and file list)")

    print(f"Successfully synced {updated} page(s)")


if __name__ == "__main__":
    main()
