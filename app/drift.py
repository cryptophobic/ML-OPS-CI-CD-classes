"""Простий drift-детектор на основі per-feature z-score проти baseline,
збереженого тренувальним скриптом у `baseline.json`.

Логіка: на кожен вхідний вектор беремо |x_i - mean_i| / std_i; якщо хоч
для однієї фічі це значення перевищує `threshold` — рахуємо запит
аномалією й повертаємо список індексів "дрейфуючих" фіч.

Цього достатньо для демонстраційного контуру (поодинокий sample). Для
продакшна тут краще б брати batch + KS-тест / MMD, але мета завдання —
показати інтеграцію детектора з інференсом і алертингом, не точність
методу."""
from __future__ import annotations

from dataclasses import dataclass
from typing import Sequence


@dataclass
class DriftDetector:
    feature_means: list[float]
    feature_stds: list[float]
    threshold: float = 3.0

    @classmethod
    def from_baseline(cls, baseline: dict, threshold: float = 3.0) -> "DriftDetector":
        return cls(
            feature_means=list(baseline["feature_means"]),
            feature_stds=list(baseline["feature_stds"]),
            threshold=threshold,
        )

    def check(self, features: Sequence[float]) -> tuple[bool, list[int], float]:
        """Повертає (is_drift, drift_features, max_zscore)."""
        if len(features) != len(self.feature_means):
            raise ValueError(
                f"feature count mismatch: got {len(features)}, "
                f"expected {len(self.feature_means)}"
            )
        drifted: list[int] = []
        max_z = 0.0
        for i, x in enumerate(features):
            z = abs((x - self.feature_means[i]) / self.feature_stds[i])
            if z > max_z:
                max_z = z
            if z > self.threshold:
                drifted.append(i)
        return bool(drifted), drifted, max_z