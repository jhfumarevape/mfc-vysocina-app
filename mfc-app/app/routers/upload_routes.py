"""File upload endpoint."""
import os
import secrets
from pathlib import Path

import aiofiles
from fastapi import APIRouter, Depends, UploadFile, File, HTTPException

from ..config import UPLOAD_DIR, MAX_UPLOAD_SIZE
from ..auth import require_permission

router = APIRouter(prefix="/upload", tags=["upload"])

ALLOWED_EXT = {".jpg", ".jpeg", ".png", ".webp", ".gif"}


@router.post("/image")
async def upload_image(
    file: UploadFile = File(...),
    user=Depends(require_permission("upload.image")),
):
    ext = Path(file.filename or "").suffix.lower()
    if ext not in ALLOWED_EXT:
        raise HTTPException(400, f"Pouze obrázky: {', '.join(sorted(ALLOWED_EXT))}")

    # Random filename
    rand = secrets.token_urlsafe(16)
    safe_name = f"u{user.id}_{rand}{ext}"
    target = UPLOAD_DIR / safe_name

    size = 0
    async with aiofiles.open(target, "wb") as out:
        while chunk := await file.read(64 * 1024):
            size += len(chunk)
            if size > MAX_UPLOAD_SIZE:
                # remove partial
                await out.close()
                os.unlink(target)
                raise HTTPException(413, f"Soubor příliš velký (max {MAX_UPLOAD_SIZE // (1024*1024)} MB)")
            await out.write(chunk)

    return {"url": f"/uploads/{safe_name}", "filename": safe_name, "size": size}
