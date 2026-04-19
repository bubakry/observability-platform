from __future__ import annotations

import asyncio
import hashlib
import hmac
import logging
import os
import random
import time
from contextlib import asynccontextmanager
from typing import Any
from uuid import uuid4

from aws_xray_sdk.core import patch_all, xray_recorder
from aws_xray_sdk.core.async_context import AsyncContext
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse, PlainTextResponse
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest

from logging_config import configure_logging


xray_recorder.configure(
    service=os.getenv("APP_NAME", "enterprise-observability-api"),
    daemon_address=os.getenv("XRAY_DAEMON_ADDRESS", "127.0.0.1:2000"),
    context=AsyncContext(),
    context_missing="LOG_ERROR",
    sampling=True,
)
patch_all()

LOGGER = configure_logging(os.getenv("LOG_LEVEL", "INFO"))
APP_SIGNING_KEY = os.getenv("APP_SIGNING_KEY", "")

REQUEST_COUNT = Counter(
    "app_requests_total",
    "Total number of HTTP requests processed by the sample application.",
    ["method", "path", "status_code"],
)

REQUEST_LATENCY = Histogram(
    "app_request_duration_seconds",
    "Latency of HTTP requests handled by the sample application.",
    ["method", "path"],
    buckets=(0.05, 0.1, 0.25, 0.5, 1, 2, 5),
)


@asynccontextmanager
async def lifespan(_: FastAPI):
    LOGGER.info(
        "FastAPI service starting",
        extra={"context": {"event": "startup", "secret_configured": bool(APP_SIGNING_KEY)}},
    )
    yield
    LOGGER.info("FastAPI service stopping", extra={"context": {"event": "shutdown"}})


app = FastAPI(
    title="AWS Enterprise Observability Platform API",
    version="1.0.0",
    lifespan=lifespan,
)


def build_context(request: Request, status_code: int, latency_ms: float, **extra: Any) -> dict[str, Any]:
    context = {
        "request_id": request.headers.get("x-request-id", str(uuid4())),
        "path": request.url.path,
        "method": request.method,
        "status_code": status_code,
        "latency_ms": round(latency_ms, 2),
        "client_ip": request.client.host if request.client else "unknown",
    }
    context.update(extra)
    return context


def sign_value(value: str) -> str | None:
    if not APP_SIGNING_KEY:
        return None

    digest = hmac.new(APP_SIGNING_KEY.encode("utf-8"), value.encode("utf-8"), hashlib.sha256)
    return digest.hexdigest()[:16]


@app.middleware("http")
async def trace_and_log_requests(request: Request, call_next):
    segment_name = f"{request.method} {request.url.path}"
    segment = xray_recorder.begin_segment(segment_name)
    segment.put_annotation("environment", os.getenv("ENVIRONMENT", "portfolio"))
    segment.put_annotation("service", os.getenv("APP_NAME", "enterprise-observability-api"))

    start = time.perf_counter()

    try:
        response = await call_next(request)
        status_code = response.status_code
        return response
    except Exception:
        status_code = 500
        LOGGER.exception(
            "Unhandled application exception",
            extra={"context": build_context(request, status_code, 0, severity="critical")},
        )
        raise
    finally:
        latency_ms = (time.perf_counter() - start) * 1000
        REQUEST_COUNT.labels(request.method, request.url.path, str(status_code)).inc()
        REQUEST_LATENCY.labels(request.method, request.url.path).observe(latency_ms / 1000)

        segment.put_http_meta("request", {"method": request.method, "url": str(request.url)})
        segment.put_http_meta("response", {"status": status_code})
        segment.put_annotation("path", request.url.path)
        segment.put_metadata("latency_ms", round(latency_ms, 2), "observability")

        LOGGER.info(
            "Request completed",
            extra={"context": build_context(request, status_code, latency_ms)},
        )
        xray_recorder.end_segment()


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/ready")
async def ready() -> dict[str, str]:
    return {"status": "ready"}


@app.get("/")
async def root() -> dict[str, str]:
    return {
        "service": "AWS Enterprise Observability Platform API",
        "status": "running",
        "secret_configured": str(bool(APP_SIGNING_KEY)).lower(),
    }


@app.get("/metrics")
async def metrics() -> PlainTextResponse:
    return PlainTextResponse(generate_latest().decode("utf-8"), media_type=CONTENT_TYPE_LATEST)


@app.get("/orders/{order_id}")
async def get_order(order_id: int) -> JSONResponse:
    with xray_recorder.in_subsegment("get_order_business_logic") as subsegment:
        simulated_latency_ms = random.randint(40, 250)
        await asyncio.sleep(simulated_latency_ms / 1000)

        status = random.choice(["processing", "fulfilled", "queued"])
        payload = {
            "order_id": order_id,
            "status": status,
            "simulated_latency_ms": simulated_latency_ms,
            "signature": sign_value(f"lookup:{order_id}:{status}"),
        }
        subsegment.put_metadata("order_lookup", payload, "observability")

    LOGGER.info(
        "Order lookup completed",
        extra={
            "context": {
                "order_id": order_id,
                "workflow": "lookup-order",
                "result_status": status,
                "simulated_latency_ms": simulated_latency_ms,
            }
        },
    )

    return JSONResponse(payload)


@app.post("/orders")
async def create_order(request: Request) -> JSONResponse:
    order_id = random.randint(1000, 9999)

    with xray_recorder.in_subsegment("process_order_workflow") as subsegment:
        processing_latency_ms = random.randint(60, 500)
        await asyncio.sleep(processing_latency_ms / 1000)
        subsegment.put_annotation("workflow", "process-order")
        subsegment.put_metadata(
            "order_processing",
            {"order_id": order_id, "processing_latency_ms": processing_latency_ms},
            "observability",
        )

    LOGGER.info(
        "Order created",
        extra={
            "context": build_context(
                request,
                201,
                processing_latency_ms,
                order_id=order_id,
                workflow="process-order",
            )
        },
    )

    return JSONResponse(
        {
            "order_id": order_id,
            "status": "accepted",
            "processing_latency_ms": processing_latency_ms,
            "signature": sign_value(f"create:{order_id}:{processing_latency_ms}"),
        },
        status_code=201,
    )


@app.get("/fail")
async def fail(request: Request) -> JSONResponse:
    LOGGER.error(
        "Synthetic failure generated for observability validation",
        extra={"context": build_context(request, 500, 0, workflow="synthetic-failure")},
    )
    return JSONResponse({"message": "synthetic failure emitted"}, status_code=500)
