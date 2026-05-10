# Fat vs Slim — порівняння Docker-образів для inference MobileNetV2

Обидва образи виконують один і той самий `inference.py` на тій самій моделі
`model.pt` і дають ідентичний топ-3 результат на `sample.jpg`:

```
1. Samoyed       0.8303
2. Pomeranian    0.0699
3. keeshond      0.0130
```

## Підсумкові метрики

| Метрика                       | `lesson3-fat`           | `lesson3-slim`         | Дельта      |
|-------------------------------|-------------------------|------------------------|-------------|
| Базовий образ                 | `python:3.9`            | `python:3.9-slim`      | —           |
| Стратегія збірки              | single-stage            | multi-stage (builder + runtime) | — |
| **Розмір образу**             | **2.75 GB**             | **692 MB**             | −2.05 GB (−75%) |
| Кількість шарів (`docker history`) | 20                  | 16                     | −4          |
| Інструменти ОС у runtime      | vim, git, wget, curl, gcc, make, build-essential | жодного з перелічених | — |
| Python-залежності у runtime   | torch, torchvision, pillow, numpy, Django | torch, pillow | прибрано 3 пакети |

## Розклад «з чого складається» кожен образ

### Fat — основні шари

| Розмір | Команда                                                    |
|--------|------------------------------------------------------------|
| ~900 MB | базовий `python:3.9` (повний build-стек, libpng, libjpeg, …) |
| 79 MB   | `apt-get install build-essential git curl wget vim unzip`  |
| 17 MB   | `pip install --upgrade pip`                                |
| 739 MB  | `pip install torch torchvision pillow Django numpy`        |
| 15 MB   | `COPY . /app/`                                             |

### Slim — основні шари (runtime stage)

| Розмір | Команда                                                    |
|--------|------------------------------------------------------------|
| ~150 MB | базовий `python:3.9-slim`                                 |
| 364 MB  | `COPY --from=builder /install /app/deps` (тільки torch + pillow, без `torch/include`, `torch/onnx`, `torch/utils/tensorboard`, `__pycache__`) |
| 15 MB   | `COPY model.pt inference.py imagenet_classes.txt sample.jpg /app/` |

## Проблеми «жирного» образу

1. **Базовий `python:3.9` тягне повний build-стек** (~900 MB сам по собі: gcc, autotools,
   libssl-dev, libxml2-dev тощо) — потрібен лише на час компіляції, не в runtime.
2. **Зайві утиліти ОС**: `vim`, `git`, `wget`, `curl`, `gcc`, `make`, `build-essential`,
   `unzip` встановлені, хоча `inference.py` про них нічого не знає. Кожна — додаткова
   поверхня атаки і CVE-навантаження.
3. **Зайві Python-пакети**:
   - `torchvision` (~150 MB) — не імпортується в `inference.py`
     (предобробка зображення зроблена на `torch` + `PIL` напряму).
   - `Django` — ML-сервіс ним не користується; згаданий лише у вимогах ДЗ.
   - `numpy` — torch працює без нього (на slim-образі лише виводиться UserWarning,
     результат той самий).
4. **`pip install` без `--no-cache-dir`** залишає wheel-кеш в `/root/.cache/pip`
   (~50 MB всередині 739-MB шару).
5. **`apt-get update` без `rm -rf /var/lib/apt/lists/*`** — індекси apt лишаються в
   образі назавжди (~30 MB).
6. **`COPY . /app/`** копіює весь контекст, у тому числі `install_dev_tools.sh`,
   `export_model.py`, `REPORT.md`, `TASK.md`, `Dockerfile.fat`, `Dockerfile.slim`, які в
   inference-контейнері не потрібні.
7. **Single-stage** — будь-яке тимчасове щось (тулчейн, кеші) залишається у фінальному
   образі, бо немає окремого runtime-шару, в який копіюється тільки потрібне.
8. **Старт контейнера повільніший** через більший розмір образу (cold pull із registry,
   завантаження непотрібних модулів при `import torch.*`).

## Що саме дало зменшення в slim

| Оптимізація                                          | Економія      |
|------------------------------------------------------|---------------|
| `python:3.9` → `python:3.9-slim`                     | ~750 MB       |
| Прибрано `apt install` (vim/git/curl/wget/build-essential) | ~80 MB |
| Прибрано torchvision, Django, numpy з runtime        | ~250 MB       |
| Multi-stage: build-кеш pip залишився у builder-стейджі | ~50 MB     |
| `find … -name __pycache__/test/tests -delete` + `torch/include`, `torch/onnx`, `torch/utils/tensorboard` | ~150 MB |
| `.dockerignore` (`.git`, `.idea`, `*.md`, `install.log`) | (захист від випадкового COPY) |
| **Разом**                                            | **≈ 2.05 GB** |

## Подальші напрямки оптимізації (нижче 692 MB)

1. **Менший базовий образ**:
   - `python:3.9-alpine` — ризик: musl несумісний з manylinux-колесами PyTorch
     (доведеться компілювати з джерел — можливо більший образ і повільна збірка).
   - **`gcr.io/distroless/python3-debian12`** — безпечний вибір: жодних shell/utils,
     лише `python3` і glibc. Очікувана економія: ще −70…−100 MB.
2. **CPU-only PyTorch wheel**: `pip install torch --index-url https://download.pytorch.org/whl/cpu`
   позбавляє CUDA stubs (~150 MB на x86_64; на arm64 ефект менший).
3. **TorchScript-only runtime**: справжня LibTorch-only збірка C++ inference (без
   Python взагалі) — фінальний образ можна скоротити до ~200 MB. Перехід коштовний,
   але доцільний для high-volume сервісу.
4. **Квантизація моделі** (`torch.quantization` → int8): MobileNetV2 з 14 MB → ~3.5 MB,
   плюс економія RAM/латентності на CPU. Не змінює розмір залежностей, але зменшує
   `model.pt` і робочу пам'ять.
5. **Strip native libs** у torch (`strip --strip-unneeded /app/deps/torch/lib/*.so`)
   — економія ~30–50 MB на arm64.
6. **Окремий шар для `model.pt`** (`COPY model.pt …` окремою інструкцією перед іншими
   COPY) — не зменшує розмір, але дозволяє кешувати при змінах коду без переupload
   моделі.
7. **`HEALTHCHECK NONE`** + `USER 1000` — не про розмір, але про корисність образу в
   проді (security best practice, що добре поєднується зі slim-філософією).

## Висновок

Перехід fat → slim дав −75% розміру (2.75 GB → 692 MB) при **ідентичному функціоналі та
результаті inference**. Головні важелі: правильний базовий образ, multi-stage, і
безжальна ревізія списку залежностей («що насправді імпортує `inference.py`?»).
Подальший крок — distroless або повний C++/LibTorch — дав би ще ~3–4× зменшення, але з
помітним ускладненням збірки.