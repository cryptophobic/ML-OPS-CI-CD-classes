# Домашнє завдання до теми «Контейнеризація ML-моделей»

Привiт! Сподiваємось, ви вже впевнено почуваєтесь у роботi з командною оболонкою та розумiєте основи роботи контейнерiв у Docker!

Ми об'єднаємо практику з тем «Основи Linux та Bash-скриптування» і «Контейнеризацiя ML-моделей» — ви не лише попрацюєте з утилiтами командного рядка, а й навчитеся створювати оптимiзованi Docker-образи для inference ML-моделей! 🐧🐳

Це завдання допоможе вам закрiпити фундаментальнi навички MLOps i попрактикувати створення скриптiв, автоматизацiю, контейнеризацiю та оптимiзацiю runtime-середовища для ML-сервiсiв.

## Опис завдання

Ваша мета:

- Створити скрипт для встановлення Docker, Docker Compose, Python і ML-залежностей.
- Побудувати 2 Docker-образи для PyTorch‑моделі: «важкий» і оптимізований (slim).
- Створити простий inference-сервіс на Python з TorchScript-моделлю.
- Оформити короткий звіт у Markdown із порівнянням та аналізом.

## Кроки виконання завдання

### 1. Bash-скрипт для підготовки середовища

Створіть Bash-скрипт `install_dev_tools.sh`, який автоматизує налаштування середовища для DevOps та ML-розробки:

- Перевіряє, чи встановлено Docker, Docker Compose, Python ≥ 3.9, pip, Django, torch, torchvision, pillow
- Якщо відсутні — встановлює:
  - Docker і Docker Compose
  - Python (через `apt` або `pyenv`, якщо система старіша)
  - `pip`
  - бібліотеки: `torch`, `torchvision`, `pillow`
- Скрипт повинен бути **ідемпотентним** — повторне виконання не повинно призводити до помилок чи повторного встановлення.

> **Бонус (опціонально):** додайте перевірку версій інструментів після встановлення та логування у файл `install.log`.

### 2. Контейнеризація ML-сервісу

- Завантажте одну з моделей `torchvision.models` (наприклад, `mobilenet_v2`) та збережіть її у форматі `.pt` (TorchScript).
- Напишіть `inference.py`, який приймає зображення на вхід і виводить топ-3 класи.
- Створіть 2 Dockerfile:

#### Fat-образ

- Базується на `ubuntu` або `python:3.9`
- Встановлює всі системні залежності та Python-бібліотеки
- Копіює модель `.pt` і скрипт `inference.py`
- Має великий розмір (>1GB)

#### Slim-образ

- Multi-stage підхід:
  - Перший етап: встановлення залежностей
  - Другий етап: лише `inference.py`, модель `.pt`, середовище виконання без `apt`
- Ціль — зменшити розмір образу до мінімуму

#### Після побудови:

- Запустіть обидва образи з будь-яким прикладом зображення
- У `report.md` або `comparison.txt` порівняйте та зазначите:
  - Розмір образів
  - Кількість шарів
  - Присутність зайвих інструментів
  - Пропозиції з подальшої оптимізації

## Підготовка та завантаження домашнього завдання

Щоб домашнє завдання було правильно оформлене та зручне для перевірки, дотримуйтесь інструкцій нижче.

### 1. Створіть окрему гілку `lesson-3` у своєму GitHub-репозиторії

У терміналі перейдіть у папку з вашим GitHub-репозиторієм і виконайте:

```bash
git checkout -b lesson-3
```

Створюється нова гілка `lesson-3`, у якій ви будете працювати над завданням.

Додайте зміни до коміту:

```bash
git add .
git commit -m "Add lesson-3: TorchScript model, Dockerfiles, report"
git push --set-upstream origin lesson-3
```

У результаті гілка `lesson-3` з'явиться у вашому репозиторії в GitHub:

```
https://gitlab.com/ваш-namespace/ваш-проєкт/-/tree/lesson-3
```

### 2. Додайте всі необхідні файли у проєкт

У гілці `lesson-3` обов'язково мають бути такі файли:

```
lesson-3/
├── inference.py
├── export_model.py
├── model.pt
├── Dockerfile.fat
├── Dockerfile.slim
├── install_dev_tools.sh
├── comparison.txt  (або report.md)
└── README.md       (з короткою інструкцією запуску)
```

> ⚠️ Використовуйте осмислені назви файлів і не забувайте про розширення `.py`, `.pt`, `.sh`, `.md`.

### 3. Створіть архів у форматі `.zip`

Переконайтесь, що ви в папці з усіма необхідними файлами, і виконайте:

```bash
zip -r ДЗ3_Прізвище_Імʼя.zip .
```

Або, якщо ви у корені репозиторію і ваші файли лежать у папці `lesson-3`:

```bash
zip -r ДЗ3_Прізвище_Андрій.zip lesson-3/
```

Перевірте вміст архіву перед завантаженням:

```bash
unzip -l ДЗ3_Прізвище_Андрій.zip
```

### 4. Завантажте архів в LMS та прикріпіть посилання на гілку GitHub (`lesson-3`).

---

✅ **Наприкінці перевірте:**

- Чи можна зібрати обидва образи (`docker build -f Dockerfile.fat/slim .`)
- Чи запускається `inference.py` усередині контейнера
- Чи `README` містить коротку інструкцію зі збірки й запуску

Це завдання чудово демонструє практичні навички MLOps — збережіть його для вашого портфоліо!

## Критерії оцінювання

Завдання оцінюється **від 0 до 100 балів**.

### 1. Bash-скрипт інсталяції — до 30 балів

- **5 балів** — скрипт перевіряє, чи встановлено `docker`, `docker-compose`, `python`, `pip`
  - → [`install_dev_tools.sh`](install_dev_tools.sh): `ensure_docker` (L60 `have docker`), `ensure_compose` (L69 `docker compose version`, L73 `docker-compose`), `ensure_python` (L85 `python_ok` ≥ 3.9), `ensure_pip` (L111 `have pip3`)
- **10 балів** — відсутні пакети встановлюються автоматично, без помилок
  - → [`install_dev_tools.sh`](install_dev_tools.sh) L59–118 (усі `ensure_*` встановлюють відсутнє через `apt_install`); перевірено в чистому `ubuntu:22.04` контейнері — exit 0
- **5 балів** — скрипт встановлює Python-залежності: `torch`, `torchvision`, `pillow`, `Django`
  - → [`install_dev_tools.sh`](install_dev_tools.sh) L11 (`PIP_PACKAGES` default), L121–142 (`ensure_pip_packages`)
- **5 балів** — скрипт є ідемпотентним: повторне виконання не викликає помилок або дублювань
  - → Кожна `ensure_*` функція робить guard-check перед install. Перевірено двома послідовними запусками: другий запуск друкує `already installed` / `already importable` для всіх пунктів і нічого не робить
- **5 балів** — *(бонус)* логування встановлення та перевірка версій записуються в `install.log`
  - → [`install_dev_tools.sh`](install_dev_tools.sh) L8 (`LOG_FILE`), L14 (`exec > >(tee -a "$LOG_FILE") 2>&1`), L144–156 (`print_versions` — фінальне резюме версій)

### 2. TorchScript модель + `inference.py` — до 25 балів

- **10 балів** — модель обрана з `torchvision.models`, збережена в `.pt` форматі за допомогою `torch.jit`
  - → [`export_model.py`](export_model.py) L8 (`models.mobilenet_v2(weights=...)`), L12–13 (`torch.jit.trace(...).save("model.pt")`); згенеровано [`model.pt`](model.pt) (~14 MB)
- **10 балів** — написано `inference.py`, який:
  - завантажує TorchScript-модель → [`inference.py`](inference.py) L44 `torch.jit.load(...)`
  - приймає зображення як аргумент або з папки → [`inference.py`](inference.py) L40 `parser.add_argument("image", type=Path, ...)`
  - виводить top-3 передбачення → [`inference.py`](inference.py) L41 (`--top-k` default 3), L51 `torch.topk`, L53–55 print loop
- **5 балів** — коректна структура проєкту, інструкція запуску `inference.py` в README
  - → Структура `lesson-3/` описана в [`README.md`](README.md) (секція «Структура»); інструкції збірки/запуску — секції 2–3

### 3. Dockerfile fat / slim — до 35 балів

- **10 балів** — fat-образ побудовано на `ubuntu` або `python`, встановлено всі залежності
  - → [`Dockerfile.fat`](Dockerfile.fat) L2 `FROM python:3.9`; L7–15 системні пакети через `apt`; L19–23 `pip install torch torchvision pillow Django numpy`. Розмір: 2.75 GB
- **10 балів** — slim-образ реалізовано через multi-stage (builder + runtime)
  - → [`Dockerfile.slim`](Dockerfile.slim) L2 `FROM python:3.9-slim AS builder`, L21 `FROM python:3.9-slim AS runtime`; runtime копіює лише `/install` з builder + 4 файли застосунку
- **10 балів** — обидва образи працюють, запускаються без помилок, дають результат
  - → `docker run --rm lesson3-fat` і `docker run --rm lesson3-slim` обидва видають ідентичний top-3 (Samoyed 0.8303, Pomeranian 0.0699, keeshond 0.0130). Команди — у [`README.md`](README.md) секція 3
- **5 балів** — добре продумана структура Dockerfile'ів, без зайвих шарів і коду
  - → [`Dockerfile.slim`](Dockerfile.slim) runtime stage = 4 шари (`COPY deps`, `COPY app`, `ENV`, `ENTRYPOINT`); навмисний prune torch (L11–14) прибирає `include`/`onnx`/`tensorboard`/`__pycache__`; [`.dockerignore`](.dockerignore) виключає `.git`, `.idea`, `*.md`, `install.log` з контексту збірки

### 4. Звіт (`comparison.txt` або `report.md`) — до 10 балів

- **4 бали** — вказано розміри образів, кількість шарів, помітна різниця fat vs slim
  - → [`REPORT.md`](REPORT.md) секція «Підсумкові метрики»: 2.75 GB / 20 шарів vs 692 MB / 16 шарів, дельта −2.05 GB (−75%)
- **3 бали** — описано проблеми з «жирним» образом: зайві пакети, повільність, обсяг
  - → [`REPORT.md`](REPORT.md) секція «Проблеми «жирного» образу» — 8 пронумерованих пунктів (повний `python:3.9` base, vim/git/curl/wget/build-essential, зайві torchvision/Django/numpy, pip cache, apt lists, broad COPY, single-stage, повільний cold pull)
- **3 бали** — наведено поради щодо оптимізації (наприклад, використання distroless, зменшення залежностей, torchscript-lite)
  - → [`REPORT.md`](REPORT.md) секція «Подальші напрямки оптимізації» — 7 ідей: distroless `gcr.io/distroless/python3-debian12`, CPU-only PyTorch wheel, повний C++/LibTorch runtime, int8-квантизація, `strip` нативних `.so`, окремий шар для `model.pt`, `USER 1000` + `HEALTHCHECK NONE`