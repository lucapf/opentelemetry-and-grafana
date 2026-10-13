import logging
from urllib.parse import urlsplit

from fastapi import FastAPI, HTTPException

import storage
import sys
from license import LicenseExpired, validate_license

app = FastAPI()

logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)
stdoutHandler = logging.StreamHandler(stream=sys.stdout)
fmt = logging.Formatter(
    "%(name)s: %(asctime)s | %(levelname)s | %(filename)s:%(lineno)s | %(process)d | %(extra)d >>> %(message)s"
)

stdoutHandler.setFormatter(fmt)
logger.addHandler(stdoutHandler)


@app.get("/hello-world")
async def root():
    logger.info("inside the hello world")
    return {"message": "Hello World"}


@app.post("/urls")
def post_url(url: str):
    try:
        remaining = validate_license()
    except LicenseExpired:
        raise HTTPException(status_code=403, detail="license expired")

    domain = urlsplit(url if "//" in url else "//" + url).hostname or "unknown"

    try:
        url_id, created = storage.store_url(url, domain)
    except storage.StorageUnavailable:
        logger.exception("url storage failed", extra={"url.domain": domain})
        raise HTTPException(status_code=500, detail="storage unavailable, retry later")

    if not created:
        logger.info(
            "url already stored", extra={"url.id": url_id, "url.domain": domain}
        )
        return {"message": "your request has already been stored!", "id": url_id}

    logger.info(
        "url stored",
        extra={
            "url.id": url_id,
            "url.domain": domain,
            "license.remaining": remaining,
        },
    )
    return {"message": "your request has been stored!", "id": url_id}
