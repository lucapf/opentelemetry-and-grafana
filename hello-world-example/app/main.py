import logging
import sys
from urllib.parse import urlsplit

import structlog
from fastapi import FastAPI, HTTPException

import storage
import license
from license import LicenseExpired, validate_license

app = FastAPI()

stdout = logging.StreamHandler(sys.stdout)
stdout.setFormatter(structlog.stdlib.ProcessorFormatter(
    foreign_pre_chain=[structlog.stdlib.add_log_level, structlog.processors.TimeStamper("%Y-%m-%d %H:%M:%S", utc=False), structlog.stdlib.ExtraAdder()],
    processor=structlog.dev.ConsoleRenderer(colors=False, sort_keys=False),
))
logging.getLogger().addHandler(stdout)
logging.getLogger().setLevel(logging.INFO)
# Uvicorn adds a colored copy of some messages (`color_message`): not for stdout nor Loki.
logging.getLogger("uvicorn.error").addFilter(lambda record: record.__dict__.pop("color_message", None) or True)
logger = logging.getLogger(__name__)
# Every log about the license carries license.remaining (the dashboard reads it from Loki): from the
# start, and at every request, whatever its outcome.
logger.info("license loaded", extra={"license.remaining": license.remaining})

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
        logger.exception("url storage failed", extra={"url.domain": domain, "license.remaining": remaining})
        raise HTTPException(status_code=500, detail="storage unavailable, retry later")

    if not created:
        logger.info(
            "url already stored",
            extra={"url.id": url_id, "url.domain": domain, "license.remaining": remaining},
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


# Uvicorn started here, not with `fastapi run`: that one installs uvicorn's own log handlers (their
# own format, not passed on to Loki); with log_config=None its logs go through the handlers above.
if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000, log_config=None)
