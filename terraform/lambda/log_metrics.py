"""LogMetrics — другий крок Step Function.

Отримує payload від ValidateData, симулює тренінг і логує "метрики" моделі.
У реальному пайплайні тут жив би запуск SageMaker-Training-Job або push до
MLflow Tracking-сервера; для демо обмежимось CloudWatch-логом і відповіддю
зі статусом succeeded.
"""
from __future__ import annotations

import json
import logging
import os
import random
from datetime import datetime, timezone

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event: dict, context) -> dict:
    logger.info("log_metrics received event: %s", json.dumps(event))

    rnd = random.Random(event.get("commit", "seed"))
    accuracy = round(0.85 + rnd.random() * 0.13, 4)
    loss = round(0.05 + rnd.random() * 0.15, 4)

    metrics = {
        "accuracy": accuracy,
        "loss": loss,
        "epochs": int(event.get("epochs", 100)),
        "learning_rate": float(event.get("learning_rate", 0.01)),
        "logged_at": datetime.now(timezone.utc).isoformat(),
        "function": os.environ.get("AWS_LAMBDA_FUNCTION_NAME", "?"),
    }
    logger.info("log_metrics result: %s", json.dumps(metrics))

    return {
        **event,
        "log_metrics": metrics,
        "status": "succeeded",
    }