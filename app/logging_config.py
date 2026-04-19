from __future__ import annotations

import json
import logging
import os
import sys
from datetime import datetime, timezone
from typing import Any

from aws_xray_sdk.core import xray_recorder


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        trace_id = "-"
        current_segment = xray_recorder.current_segment()
        if current_segment is not None:
            trace_id = current_segment.trace_id

        payload: dict[str, Any] = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "service": os.getenv("APP_NAME", "enterprise-observability-api"),
            "environment": os.getenv("ENVIRONMENT", "portfolio"),
            "trace_id": trace_id,
        }

        if hasattr(record, "context") and isinstance(record.context, dict):
            payload.update(record.context)

        if record.exc_info:
            payload["exception"] = self.formatException(record.exc_info)

        return json.dumps(payload, default=str)


def configure_logging(level: str = "INFO") -> logging.Logger:
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JsonFormatter())

    root_logger = logging.getLogger()
    root_logger.handlers.clear()
    root_logger.addHandler(handler)
    root_logger.setLevel(level)

    logging.getLogger("uvicorn").handlers.clear()
    logging.getLogger("uvicorn.error").handlers.clear()
    logging.getLogger("uvicorn.access").handlers.clear()

    return logging.getLogger("enterprise-observability")

