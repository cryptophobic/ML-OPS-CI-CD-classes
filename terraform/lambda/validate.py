"""ValidateData — перший крок Step Function.

Симулює перевірку вхідних даних перед тренінгом:
- читає event (передано з aws stepfunctions start-execution --input);
- мінімально верифікує наявність обовʼязкових полів (`source`, `commit`);
- логує у CloudWatch і повертає збагачений payload для наступного етапу.

У "справжньому" пайплайні тут жила б перевірка схеми датасету / DVC pull /
S3 listing — для демо обмежимось перевіркою payload і метаданих.
"""
from __future__ import annotations

import json
import logging
import os
from datetime import datetime, timezone

logger = logging.getLogger()
logger.setLevel(logging.INFO)

REQUIRED_FIELDS = ("source", "commit")


def lambda_handler(event: dict, context) -> dict:
    logger.info("validate received event: %s", json.dumps(event))

    missing = [k for k in REQUIRED_FIELDS if k not in event]
    if missing:
        logger.error("validation failed, missing fields: %s", missing)
        raise ValueError(f"Missing required fields: {missing}")

    rows_scanned = int(event.get("rows", 1500))
    bad_rows = int(event.get("bad_rows", 0))
    ratio = bad_rows / rows_scanned if rows_scanned else 0.0

    if ratio > 0.05:
        raise ValueError(f"Too many bad rows: {ratio:.2%}")

    result = {
        **event,
        "validate": {
            "status": "ok",
            "rows_scanned": rows_scanned,
            "bad_rows": bad_rows,
            "bad_ratio": round(ratio, 4),
            "checked_at": datetime.now(timezone.utc).isoformat(),
            "function": os.environ.get("AWS_LAMBDA_FUNCTION_NAME", "?"),
        },
    }
    logger.info("validate result: %s", json.dumps(result["validate"]))
    return result