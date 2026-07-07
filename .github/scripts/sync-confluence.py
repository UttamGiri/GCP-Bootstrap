#!/usr/bin/env python3
"""Sync docs/*.md to Confluence pages using docs/confluence/page-mapping.json."""

from __future__ import annotations

import argparse
import base64
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


def markdown_to_storage(md: str) -> str:
    if markdown is None:
        raise SystemExit("markdown package is required: pip install markdown")

    html = markdown.markdown(
        md,
        extensions=["tables", "fenced_code", "sane_lists", "nl2br"],
    )

    # Confluence storage format expects a single root; wrap fragments.
    if not html.strip():
        return "<p></p>"

    # Mermaid blocks do not render in Confluence without a plugin — show as code.
    html = re.sub(
        r"<pre><code class=\"language-mermaid\">(.*?)</code></pre>",
        r'<ac:structured-macro ac:name="code"><ac:parameter ac:name="language">text</ac:parameter>'
        r"<ac:plain-text-body><![CDATA[\1]]></ac:plain-text-body></ac:structured-macro>",
        html,
        flags=re.DOTALL,
    )

    return html


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


def update_page(
    base_url: str,
    auth_header: str,
    page_id: str,
    storage_html: str,
) -> None:
    base = base_url.rstrip("/")
    get_url = f"{base}/wiki/rest/api/content/{page_id}?expand=version"
    current = api_request("GET", get_url, auth_header)
    version = current["version"]["number"]
    # Keep the page title Confluence already has — renaming via API fails if
    # another page in the same space already uses the mapped title.
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
    put_url = f"{base}/wiki/rest/api/content/{page_id}"
    api_request("PUT", put_url, auth_header, payload)


def is_placeholder(page_id: str) -> bool:
    return not page_id or page_id.startswith("REPLACE_WITH_")


def sync_file(
    filename: str,
    mapping: dict[str, dict[str, str]],
    base_url: str,
    auth_header: str,
) -> None:
    if filename not in mapping:
        print(f"skip {filename}: not in page mapping")
        return

    entry = mapping[filename]
    page_id = entry["page_id"]

    if is_placeholder(page_id):
        print(f"skip {filename}: page_id is still a placeholder ({page_id})")
        return

    md_path = DOCS_DIR / filename
    if not md_path.exists():
        print(f"skip {filename}: file not found at {md_path}")
        return

    md = md_path.read_text(encoding="utf-8")
    storage_html = markdown_to_storage(md)
    update_page(base_url, auth_header, page_id, storage_html)
    print(f"updated {filename} -> page {page_id}")


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
    email = os.environ.get("CONFLUENCE_EMAIL", "uttamgiri32@gmail.com").strip()
    token = os.environ.get("CONFLUENCE_API_TOKEN", "").strip()

    if not token:
        raise SystemExit("Set CONFLUENCE_API_TOKEN (Atlassian API token)")

    auth = base64.b64encode(f"{email}:{token}".encode()).decode()
    auth_header = f"Basic {auth}"

    mapping = load_mapping(args.env)
    files = args.files or sorted(mapping.keys())

    for filename in files:
        sync_file(filename, mapping, base_url, auth_header)


if __name__ == "__main__":
    main()
