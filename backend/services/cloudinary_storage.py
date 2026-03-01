# -*- coding: utf-8 -*-
"""
Cloudinary Storage Service — RPM edition
=========================================
Minimal service: stores avatar metadata (RPM GLB URLs + user info) as
JSON blobs in Cloudinary.  No trimesh, no GLB generation — the GLB URL
comes directly from Ready Player Me.
"""

import json
import logging
from datetime import datetime, timezone

import cloudinary
import cloudinary.uploader
import cloudinary.api

logger = logging.getLogger(__name__)

_RAW    = "raw"
_FOLDER = "genzfit_avatars"


class CloudinaryStorageService:
    """
    Stores and retrieves avatar metadata via Cloudinary raw-file upload.
    Each entry is a small JSON blob keyed by genzfit_avatars/<uid>/<ts>.json
    """

    def __init__(self, cloud_name: str, api_key: str, api_secret: str):
        cloudinary.config(cloud_name=cloud_name, api_key=api_key, api_secret=api_secret)
        logger.info("CloudinaryStorageService ready (cloud=%s)", cloud_name)

    async def save_avatar_metadata(self, user_id: str, metadata: dict) -> str:
        ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        public_id = f"{_FOLDER}/{user_id}/{ts}"
        payload = json.dumps(metadata, default=str).encode("utf-8")
        result = cloudinary.uploader.upload(
            payload,
            public_id=public_id,
            resource_type=_RAW,
            overwrite=True,
            tags=[user_id, "avatar_metadata"],
        )
        logger.info("Saved avatar metadata → %s", result.get("public_id"))
        return result.get("public_id", public_id)

    async def get_physique_history(self, user_id: str, limit: int = 30) -> list:
        import urllib.request
        try:
            result = cloudinary.api.resources(
                type="upload",
                resource_type=_RAW,
                prefix=f"{_FOLDER}/{user_id}/",
                max_results=limit,
            )
        except Exception as e:
            logger.warning("Cloudinary list failed: %s", e)
            return []

        entries = []
        resources = sorted(
            result.get("resources", []),
            key=lambda r: r.get("created_at", ""),
            reverse=True,
        )[:limit]

        for r in resources:
            url = r.get("secure_url", "")
            if not url:
                continue
            try:
                with urllib.request.urlopen(url, timeout=5) as resp:
                    data = json.loads(resp.read().decode("utf-8"))
                entries.append(data)
            except Exception as ex:
                logger.warning("Failed to fetch %s: %s", url, ex)

        return entries
