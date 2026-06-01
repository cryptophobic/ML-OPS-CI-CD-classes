"""
Тренує SGDClassifier на Iris із сіткою (learning_rate, epochs), логує
параметри/метрики/модель у MLflow, пушить accuracy+loss у Prometheus
PushGateway з міткою run_id, копіює найкращу модель у `best_model/`.

Перед запуском (з основної теки проєкту):

    kubectl port-forward -n mlflow svc/mlflow              5000:5000 &
    kubectl port-forward -n monitoring \
        svc/prometheus-pushgateway                          9091:9091 &
    kubectl port-forward -n mlflow svc/minio               9000:9000 &

    export MLFLOW_TRACKING_URI=http://localhost:5000
    export MLFLOW_S3_ENDPOINT_URL=http://localhost:9000
    export AWS_ACCESS_KEY_ID=mlflow
    export AWS_SECRET_ACCESS_KEY=mlflow-secret-key
    export AWS_DEFAULT_REGION=us-east-1
    export PUSHGATEWAY_URL=http://localhost:9091

    python experiments/train_and_push.py
"""
from __future__ import annotations

import os
import shutil
from pathlib import Path

import mlflow
import mlflow.sklearn
import numpy as np
from prometheus_client import CollectorRegistry, Gauge, push_to_gateway
from sklearn.datasets import load_iris
from sklearn.linear_model import SGDClassifier
from sklearn.metrics import accuracy_score, log_loss
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler

EXPERIMENT_NAME = "iris-sgd-grid"
PUSHGATEWAY_JOB = "mlflow_experiments"
BEST_MODEL_DIR = Path(__file__).resolve().parent.parent / "best_model"

HYPERPARAM_GRID = [
    {"learning_rate_init": 0.001, "epochs": 50},
    {"learning_rate_init": 0.01,  "epochs": 50},
    {"learning_rate_init": 0.05,  "epochs": 100},
    {"learning_rate_init": 0.1,   "epochs": 100},
    {"learning_rate_init": 0.3,   "epochs": 200},
]


def push_metrics(run_id: str, accuracy: float, loss: float) -> None:
    """Publish per-run accuracy/loss to Prometheus PushGateway."""
    gateway = os.environ.get("PUSHGATEWAY_URL", "http://localhost:9091")
    registry = CollectorRegistry()
    Gauge(
        "mlflow_accuracy",
        "Test accuracy of an MLflow run",
        ["run_id", "experiment"],
        registry=registry,
    ).labels(run_id=run_id, experiment=EXPERIMENT_NAME).set(accuracy)
    Gauge(
        "mlflow_loss",
        "Test log loss of an MLflow run",
        ["run_id", "experiment"],
        registry=registry,
    ).labels(run_id=run_id, experiment=EXPERIMENT_NAME).set(loss)
    push_to_gateway(
        gateway,
        job=PUSHGATEWAY_JOB,
        grouping_key={"run_id": run_id},
        registry=registry,
    )


def train_once(params: dict, X_train, X_test, y_train, y_test):
    with mlflow.start_run() as run:
        mlflow.log_params(params)

        model = SGDClassifier(
            loss="log_loss",
            learning_rate="constant",
            eta0=params["learning_rate_init"],
            max_iter=params["epochs"],
            tol=None,
            random_state=42,
        )
        model.fit(X_train, y_train)

        y_pred = model.predict(X_test)
        y_proba = model.predict_proba(X_test)
        acc = accuracy_score(y_test, y_pred)
        loss = log_loss(y_test, y_proba, labels=np.unique(y_train))

        mlflow.log_metric("accuracy", acc)
        mlflow.log_metric("loss", loss)
        mlflow.sklearn.log_model(model, artifact_path="model")

        push_metrics(run.info.run_id, acc, loss)

        print(
            f"run_id={run.info.run_id}  "
            f"lr={params['learning_rate_init']}  "
            f"epochs={params['epochs']}  "
            f"accuracy={acc:.4f}  loss={loss:.4f}"
        )

        return {
            "run_id": run.info.run_id,
            "accuracy": acc,
            "loss": loss,
            "params": params,
        }


def main() -> None:
    tracking_uri = os.environ.get("MLFLOW_TRACKING_URI", "http://localhost:5000")
    mlflow.set_tracking_uri(tracking_uri)
    mlflow.set_experiment(EXPERIMENT_NAME)
    print(f"MLflow tracking URI: {tracking_uri}")

    iris = load_iris()
    X_train, X_test, y_train, y_test = train_test_split(
        iris.data, iris.target, test_size=0.2, random_state=42, stratify=iris.target
    )
    scaler = StandardScaler().fit(X_train)
    X_train_s, X_test_s = scaler.transform(X_train), scaler.transform(X_test)

    results = [
        train_once(p, X_train_s, X_test_s, y_train, y_test)
        for p in HYPERPARAM_GRID
    ]

    best = max(results, key=lambda r: r["accuracy"])
    print(
        f"\nBEST: run_id={best['run_id']}  accuracy={best['accuracy']:.4f}  "
        f"params={best['params']}"
    )

    if BEST_MODEL_DIR.exists():
        shutil.rmtree(BEST_MODEL_DIR)
    BEST_MODEL_DIR.mkdir(parents=True, exist_ok=True)

    artifact_uri = f"runs:/{best['run_id']}/model"
    mlflow.artifacts.download_artifacts(
        artifact_uri=artifact_uri, dst_path=str(BEST_MODEL_DIR)
    )
    (BEST_MODEL_DIR / "BEST_RUN.txt").write_text(
        f"run_id={best['run_id']}\n"
        f"accuracy={best['accuracy']:.4f}\n"
        f"loss={best['loss']:.4f}\n"
        f"params={best['params']}\n"
    )
    print(f"Best model artifacts saved to {BEST_MODEL_DIR}")


if __name__ == "__main__":
    main()