"""FastAPI inference-сервіс для digits-classifier.

На старті:
  - підключається до MLflow Tracking URI;
  - завантажує модель `MODEL_NAME` зі стадії `MODEL_STAGE` через
    Model Registry;
  - читає baseline-артефакт із того ж run-а (per-feature mean/std) та
    конструює drift-детектор.

На кожен `/predict`:
  - валідація через pydantic (рівно 64 фічі для digits);
  - інференс;
  - перевірка дрейфу: якщо max z-score > `DRIFT_THRESHOLD`, інкрементимо
    лічильник `inference_drift_events_total`, пишемо структуроване JSON-
    повідомлення у stdout (Promtail зчитає в Loki) та явний рядок
    "Drift detected" (як того вимагає TASK.md).

`/metrics` віддає Prometheus-формат для ServiceMonitor.
`/health` — liveness."""
from __future__ import annotations

import json
import logging
import os
import sys
import time
from contextlib import asynccontextmanager
from typing import Annotated

import mlflow
import mlflow.sklearn
from fastapi import FastAPI, HTTPException
from mlflow.tracking import MlflowClient
from prometheus_client import (
    CONTENT_TYPE_LATEST,
    Counter,
    Gauge,
    Histogram,
    generate_latest,
)
from pydantic import BaseModel, Field
from starlette.responses import Response

from app.drift import DriftDetector

MODEL_NAME = os.environ.get("MODEL_NAME", "digits-classifier")
MODEL_STAGE = os.environ.get("MODEL_STAGE", "Production")
DRIFT_THRESHOLD = float(os.environ.get("DRIFT_THRESHOLD", "3.0"))
N_FEATURES = 64

logging.basicConfig(
    level=logging.INFO,
    format="%(message)s",
    stream=sys.stdout,
)
logger = logging.getLogger("inference")

REQUEST_COUNTER = Counter(
    "inference_requests_total",
    "Inference requests processed",
    ["status"],
)
PREDICTION_LATENCY = Histogram(
    "inference_latency_seconds",
    "End-to-end /predict latency in seconds",
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5),
)
DRIFT_COUNTER = Counter(
    "inference_drift_events_total",
    "Inference requests flagged as drift",
)
MAX_ZSCORE = Histogram(
    "inference_max_zscore",
    "Maximum per-feature z-score seen on a single /predict request",
    buckets=(0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 4.0, 6.0, 10.0),
)
MODEL_VERSION_INFO = Gauge(
    "inference_model_version_info",
    "1 for currently loaded MLflow Model Registry version",
    ["model", "stage", "version", "run_id"],
)

state: dict = {}


def _emit(event: str, level: int = logging.INFO, **fields) -> None:
    """Один структурований JSON-рядок на stdout — Promtail зчитає це у Loki
    як єдине лог-повідомлення з потрібними полями."""
    payload = {"event": event, "ts": time.time(), **fields}
    logger.log(level, json.dumps(payload))


@asynccontextmanager
async def lifespan(_: FastAPI):
    tracking_uri = os.environ["MLFLOW_TRACKING_URI"]
    mlflow.set_tracking_uri(tracking_uri)
    client = MlflowClient()

    model_uri = f"models:/{MODEL_NAME}/{MODEL_STAGE}"
    _emit("model_loading", uri=model_uri, tracking_uri=tracking_uri)
    state["model"] = mlflow.sklearn.load_model(model_uri)

    versions = client.get_latest_versions(MODEL_NAME, stages=[MODEL_STAGE])
    if not versions:
        raise RuntimeError(
            f"no version found for {MODEL_NAME} at stage {MODEL_STAGE}"
        )
    mv = versions[0]
    baseline = mlflow.artifacts.load_dict(f"runs:/{mv.run_id}/baseline.json")
    detector = DriftDetector.from_baseline(baseline, threshold=DRIFT_THRESHOLD)
    state["model_version"] = mv.version
    state["model_run_id"] = mv.run_id
    state["drift"] = detector
    state["n_features"] = baseline["n_features"]

    MODEL_VERSION_INFO.labels(
        model=MODEL_NAME, stage=MODEL_STAGE, version=str(mv.version), run_id=mv.run_id
    ).set(1)

    _emit(
        "model_loaded",
        model=MODEL_NAME,
        stage=MODEL_STAGE,
        version=mv.version,
        run_id=mv.run_id,
        n_features=baseline["n_features"],
        drift_threshold=DRIFT_THRESHOLD,
    )
    yield


app = FastAPI(title="digits-inference", lifespan=lifespan)


class PredictRequest(BaseModel):
    features: Annotated[
        list[float],
        Field(min_length=N_FEATURES, max_length=N_FEATURES),
    ]


class PredictResponse(BaseModel):
    prediction: int
    probabilities: list[float]
    drift: bool
    drift_features: list[int]
    max_zscore: float
    model_version: str
    model_stage: str


def _predict(features: list[float]) -> dict:
    """Чиста функція передбачення — окремо від HTTP-обгортки, як того
    вимагає TASK.md ("логіка в окремому predict()")."""
    proba = state["model"].predict_proba([features])[0]
    pred = int(proba.argmax())
    is_drift, drift_features, max_z = state["drift"].check(features)
    return {
        "prediction": pred,
        "probabilities": proba.tolist(),
        "drift": is_drift,
        "drift_features": drift_features,
        "max_zscore": max_z,
    }


@app.get("/health")
def health():
    return {
        "status": "ok",
        "model_loaded": "model" in state,
        "model_version": state.get("model_version"),
    }


@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.post("/predict", response_model=PredictResponse)
def predict(req: PredictRequest):
    start = time.perf_counter()
    try:
        result = _predict(req.features)
        if result["drift"]:
            DRIFT_COUNTER.inc()
            _emit(
                "drift_detected",
                level=logging.WARNING,
                drift_features=result["drift_features"],
                max_zscore=result["max_zscore"],
                threshold=DRIFT_THRESHOLD,
                prediction=result["prediction"],
                model_version=state["model_version"],
            )
            # Явний рядок, що його шукає рев'ювер за TASK.md
            print("Drift detected", flush=True)
        _emit(
            "predict",
            prediction=result["prediction"],
            drift=result["drift"],
            max_zscore=result["max_zscore"],
            model_version=state["model_version"],
        )
        MAX_ZSCORE.observe(result["max_zscore"])
        REQUEST_COUNTER.labels(status="ok").inc()
        return PredictResponse(
            prediction=result["prediction"],
            probabilities=result["probabilities"],
            drift=result["drift"],
            drift_features=result["drift_features"],
            max_zscore=result["max_zscore"],
            model_version=str(state["model_version"]),
            model_stage=MODEL_STAGE,
        )
    except HTTPException:
        REQUEST_COUNTER.labels(status="client_error").inc()
        raise
    except Exception as exc:
        REQUEST_COUNTER.labels(status="server_error").inc()
        _emit("predict_failed", level=logging.ERROR, error=str(exc))
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    finally:
        PREDICTION_LATENCY.observe(time.perf_counter() - start)