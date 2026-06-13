"""
Тренує LogisticRegression на sklearn-digits (8x8 рукописних цифр, 64 фічі,
10 класів), логує параметри/метрики у MLflow, реєструє модель у Model
Registry під іменем `digits-classifier` та перемикає її в стадію
`Production`. До артефактів run-а додає `baseline.json` з per-feature
mean/std — це baseline для drift-детектора у FastAPI.

Призначено до запуску як Kubernetes Job всередині кластера (де MLflow
доступний за service DNS) або локально з port-forward на MLflow/MinIO.

Очікувані env-змінні:

    MLFLOW_TRACKING_URI       — обовʼязково
    MLFLOW_S3_ENDPOINT_URL    — MinIO endpoint
    AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_DEFAULT_REGION
    MODEL_NAME                — default `digits-classifier`
    PROMOTE_STAGE             — default `Production`
    PUSHGATEWAY_URL           — опційно, для метрик тренування
"""
from __future__ import annotations

import json
import os
import time

import mlflow
import mlflow.sklearn
import numpy as np
from mlflow.tracking import MlflowClient
from sklearn.datasets import load_digits
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, log_loss
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler

EXPERIMENT_NAME = os.environ.get("MLFLOW_EXPERIMENT_NAME", "digits-classifier")
MODEL_NAME = os.environ.get("MODEL_NAME", "digits-classifier")
PROMOTE_STAGE = os.environ.get("PROMOTE_STAGE", "Production")
PUSHGATEWAY_URL = os.environ.get("PUSHGATEWAY_URL")


def baseline_from(X: np.ndarray, y: np.ndarray) -> dict:
    """Per-feature mean/std рахуються по сирих (не масштабованих) фічах.
    FastAPI приймає сирі вектори та проганяє їх через тренований Pipeline
    (StandardScaler у голові), тож drift-детектор має дивитися на ту саму
    шкалу, що й вхідний запит."""
    stds = X.std(axis=0, ddof=0)
    stds = np.where(stds < 1e-6, 1e-6, stds)
    return {
        "feature_means": X.mean(axis=0).tolist(),
        "feature_stds": stds.tolist(),
        "n_features": int(X.shape[1]),
        "classes": sorted(int(c) for c in set(y.tolist())),
        "training_samples": int(X.shape[0]),
        "trained_at": int(time.time()),
    }


def push_training_metrics(run_id: str, accuracy: float, loss: float) -> None:
    if not PUSHGATEWAY_URL:
        return
    from prometheus_client import CollectorRegistry, Gauge, push_to_gateway

    reg = CollectorRegistry()
    Gauge(
        "training_accuracy",
        "Test accuracy of the latest training run",
        ["run_id"],
        registry=reg,
    ).labels(run_id=run_id).set(accuracy)
    Gauge(
        "training_loss",
        "Test log-loss of the latest training run",
        ["run_id"],
        registry=reg,
    ).labels(run_id=run_id).set(loss)
    push_to_gateway(
        PUSHGATEWAY_URL,
        job="digits_training",
        grouping_key={"run_id": run_id},
        registry=reg,
    )


def main() -> None:
    tracking_uri = os.environ["MLFLOW_TRACKING_URI"]
    mlflow.set_tracking_uri(tracking_uri)
    mlflow.set_experiment(EXPERIMENT_NAME)
    print(f"MLflow tracking URI: {tracking_uri}")

    digits = load_digits()
    X_train, X_test, y_train, y_test = train_test_split(
        digits.data,
        digits.target,
        test_size=0.2,
        random_state=42,
        stratify=digits.target,
    )

    params = {"C": 1.0, "max_iter": 500, "solver": "lbfgs"}
    with mlflow.start_run() as run:
        mlflow.log_params(params)
        mlflow.set_tag("dataset", "sklearn-digits")

        pipeline = Pipeline(
            [
                ("scaler", StandardScaler()),
                ("classifier", LogisticRegression(**params, random_state=42)),
            ]
        )
        pipeline.fit(X_train, y_train)

        y_pred = pipeline.predict(X_test)
        y_proba = pipeline.predict_proba(X_test)
        acc = accuracy_score(y_test, y_pred)
        loss = log_loss(y_test, y_proba, labels=list(range(10)))

        mlflow.log_metric("accuracy", acc)
        mlflow.log_metric("loss", loss)

        mlflow.sklearn.log_model(
            pipeline,
            artifact_path="model",
            registered_model_name=MODEL_NAME,
        )

        baseline = baseline_from(X_train, y_train)
        mlflow.log_dict(baseline, "baseline.json")

        push_training_metrics(run.info.run_id, acc, loss)
        print(
            f"run_id={run.info.run_id}  accuracy={acc:.4f}  loss={loss:.4f}"
        )
        run_id = run.info.run_id

    client = MlflowClient()
    versions = client.search_model_versions(f"name='{MODEL_NAME}'")
    fresh = max(versions, key=lambda v: int(v.version))
    if fresh.run_id != run_id:
        print(
            f"WARNING: newest registered version {fresh.version} "
            f"run_id={fresh.run_id} does not match training run {run_id}"
        )
    client.transition_model_version_stage(
        name=MODEL_NAME,
        version=fresh.version,
        stage=PROMOTE_STAGE,
        archive_existing_versions=True,
    )
    print(f"Registered {MODEL_NAME} v{fresh.version} → stage={PROMOTE_STAGE}")

    summary = {
        "model": MODEL_NAME,
        "version": fresh.version,
        "stage": PROMOTE_STAGE,
        "run_id": run_id,
        "accuracy": acc,
        "loss": loss,
    }
    print(json.dumps({"event": "training_completed", **summary}))


if __name__ == "__main__":
    main()