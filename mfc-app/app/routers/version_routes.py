"""Auto-update endpoint — vrací nejnovější verzi z GitHub Releases."""
from __future__ import annotations

import time
import logging
from typing import Any

import httpx
from fastapi import APIRouter, HTTPException

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["version"])

GITHUB_REPO = "jhfumarevape/mfc-vysocina-app"
CACHE_TTL_SECONDS = 300  # 5 min


class _Cache:
    data: dict[str, Any] | None = None
    expires_at: float = 0


_cache = _Cache()


def _parse_version_from_tag(tag: str) -> str:
    """v0.1.0+3 -> 0.1.0+3  (jen bez prefix 'v', build number zachovat).

    Frontend porovnává verzi pomocí `[+.]` splitu — build number je
    nedílná součást, jinak by se neaktualizovalo mezi 0.1.0+1 a 0.1.0+5.
    """
    return tag.lstrip("v")


async def _fetch_latest() -> dict[str, Any]:
    """Stahne nejnovejsi release z GitHub API a vrati zjednodusenou strukturu."""
    url = f"https://api.github.com/repos/{GITHUB_REPO}/releases/latest"
    async with httpx.AsyncClient(timeout=8.0) as client:
        resp = await client.get(url, headers={"Accept": "application/vnd.github+json"})
        if resp.status_code == 404:
            return {
                "latest_version": "0.0.0",
                "download_url": "",
                "release_notes": "Žádný release zatím.",
                "tag": None,
                "released_at": None,
            }
        resp.raise_for_status()
        data = resp.json()

    tag = data.get("tag_name", "")
    version = _parse_version_from_tag(tag)
    notes = data.get("body") or ""

    apk_asset = None
    for asset in data.get("assets", []):
        if str(asset.get("name", "")).lower().endswith(".apk"):
            apk_asset = asset
            break

    download_url = apk_asset["browser_download_url"] if apk_asset else ""
    return {
        "latest_version": version,
        "download_url": download_url,
        "release_notes": notes,
        "tag": tag,
        "released_at": data.get("published_at"),
    }


@router.get("/version")
async def get_version():
    """
    Vraci nejnovejsi verzi appky a URL k APK souboru.

    Frontend (mfc_app/lib/services/update_checker.dart) tohle pouzije
    k zobrazeni banneru v MainShell, kdyz najde novejsi build nez ten
    na telefonu.
    """
    now = time.time()
    if _cache.data and now < _cache.expires_at:
        return _cache.data

    try:
        result = await _fetch_latest()
    except Exception as e:
        logger.warning(f"GitHub API fetch failed: {e}")
        # Pokud uz neco mame v cache (i kdyz expired), radsi vratit nez 500
        if _cache.data:
            return _cache.data
        raise HTTPException(status_code=503, detail=f"GitHub API unreachable: {e}")

    _cache.data = result
    _cache.expires_at = now + CACHE_TTL_SECONDS
    return result
