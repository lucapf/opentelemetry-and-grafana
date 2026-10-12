import logging
import os

from opentelemetry import trace

logger = logging.getLogger(__name__)
tracer = trace.get_tracer(__name__)

remaining = int(os.environ.get("LICENSE_REQUESTS", "10"))


class LicenseExpired(Exception):
    pass


@tracer.start_as_current_span(
    "validate_license", record_exception=False, set_status_on_exception=False
)
def validate_license() -> int:
    global remaining
    if remaining == 0:
        logger.warning("license expired")
        raise LicenseExpired()
    remaining -= 1
    return remaining
