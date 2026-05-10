# lesson-3 — Контейнеризація MobileNetV2 inference

TorchScript-експорт `mobilenet_v2`, інференс-скрипт + два Docker-образи
(fat vs multi-stage slim) і звіт-порівняння.

## Структура

```
lesson-3/
├── export_model.py        # експортує mobilenet_v2 у model.pt (TorchScript)
├── model.pt               # збережена модель (~14 MB)
├── inference.py           # CLI: завантажує model.pt, друкує top-3 класи
├── imagenet_classes.txt   # 1000 ImageNet міток
├── sample.jpg             # тестове зображення (Samoyed)
├── install_dev_tools.sh   # ідемпотентний host-setup для Debian/Ubuntu
├── Dockerfile.fat         # single-stage, базовий рівень («жирний»)
├── Dockerfile.slim        # multi-stage builder + runtime
├── REPORT.md              # порівняння fat vs slim
├── TASK.md                # повний опис ДЗ + критерії оцінювання з посиланнями
└── .dockerignore
```

## Передумови

- Docker (тільки Docker — все інше встановлюється всередині образів).
- Опціонально: `bash` для запуску `install_dev_tools.sh` на чистому Debian/Ubuntu.

## 1. Експорт моделі (один раз; `model.pt` уже в репо)

Якщо потрібно перегенерувати:

```bash
docker run --rm -v "$PWD":/work -w /work python:3.9-slim sh -c \
    "pip install --no-cache-dir torch==2.2.2 torchvision==0.17.2 && python export_model.py"
```

## 2. Збірка образів

```bash
docker build -f Dockerfile.fat  -t lesson3-fat  .
docker build -f Dockerfile.slim -t lesson3-slim .
```

Очікувані розміри: fat ≈ 2.75 GB, slim ≈ 692 MB.

## 3. Запуск inference

На вкладеному `sample.jpg`:

```bash
docker run --rm lesson3-fat                  # CMD за замовчуванням = sample.jpg
docker run --rm lesson3-slim
```

На власному зображенні (монтуємо файл у контейнер):

```bash
docker run --rm -v "$PWD/my-photo.jpg":/app/in.jpg lesson3-slim in.jpg
```

Очікуваний вивід для `sample.jpg`:

```
Top-3 predictions for sample.jpg:
  1. Samoyed                                   0.8303
  2. Pomeranian                                0.0699
  3. keeshond                                  0.0130
```

## 4. Host-setup скрипт (опціонально)

Для чистого Debian/Ubuntu хоста:

```bash
sudo bash install_dev_tools.sh
# або з кастомним списком pip-пакетів:
sudo PIP_PACKAGES="pillow Django" bash install_dev_tools.sh
```

Скрипт ідемпотентний — повторне виконання нічого не встановлює, лише друкує статус.
Лог пишеться в `install.log`.

## 5. Порівняння fat vs slim

Деталі — у [`REPORT.md`](REPORT.md).
Коротко: −75% розміру (2.75 GB → 692 MB) при ідентичному результаті інференсу.

## Перевірка перед здаванням

```bash
docker build -f Dockerfile.fat  -t lesson3-fat  . && docker run --rm lesson3-fat
docker build -f Dockerfile.slim -t lesson3-slim . && docker run --rm lesson3-slim
docker images | grep lesson3
```