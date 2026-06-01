Автоматизоване тренування моделей

Вітаємо!

У цьому завданні ми переходимо до повноцінної автоматизації тренування ML-моделей.



Ви вже знайомі з контейнеризацією, деплоєм моделей через Helm та GitOps, логуванням метрик і сповіщеннями. Але реальний MLOps‑процес не обходиться без контрольованого, відтворюваного тренування моделей — і саме його ми автоматизуємо через GitLab CI та AWS Step Functions.



Мета

Створити Step Function в AWS, яка запускає пайплайн тренування з кількох кроків;
Створити Lambda-функції для окремих етапів (наприклад, валідація та логування);
Розгорнути інфраструктуру через Terraform;
Налаштувати GitLab CI для автоматичного запуску Step Function при push.


Завдання

Очікувана структура проєкту

mlops-train-automation/
├── terraform/
│  ├── main.tf
│  ├── variables.tf
│  └── lambda/
│    ├── validate.py
│    ├── log_metrics.py
│    ├── validate.zip
│    └── log_metrics.zip
├── .gitlab-ci.yml
├── README.md



1. Створити Lambda-функції

Створіть terraform/lambda/validate.py та log_metrics.py;
Логіка може бути умовною (наприклад, print("Validating data..."));
Зберіть архіви:
cd terraform/lambda
zip validate.zip validate.py
zip log_metrics.zip log_metrics.py



2. Написати Terraform конфігурацію

У файлі terraform/main.tf:
- Створіть IAM ролі для Lambda та Step Function;

- Опишіть 2 Lambda-функції;

- Опишіть Step Function з двома етапами, які послідовно викликають функції validate → log_metrics;

Після чого:
terraform init
terraform apply



3. Налаштувати GitLab CI

Створіть файл .gitlab-ci.yml;
Додайте job, який запускає Step Function:
train-model:
 stage: train
 image: amazon/aws-cli:2.15.0
 script:
  - aws stepfunctions start-execution \
    --state-machine-arn arn:aws:states:... \
    --name "train-$(date +%s)" \
    --input '{"source":"gitlab-ci", "commit":"'$CI_COMMIT_SHORT_SHA'"}'

Додайте змінні AWS у GitLab CI (через CI Settings або OIDC, якщо маєте змогу).


4. Створити README.md

Документація повинна містити:
- Як зібрати Lambda-архіви;

- Як розгорнути інфраструктуру через Terraform;

- Як вручну запустити Step Function;

- Як працює GitLab CI та які змінні потрібні;

- Приклад JSON, який передається.



Результати виконання

AWS створено Step Function із 2+ кроків (валідація, логування), що викликають Lambda-функції;
Lambda-функції реалізовані на Python, збережені у .zip архівах;
Інфраструктура повністю описана в Terraform (main.tf);
GitLab CI запускає Step Function через aws stepfunctions start-execution;
Вхідні параметри передаються через JSON, job прив’язаний до події push;
У проєкті є README.md, що містить повну інструкцію запуску, перевірки та опис архітектури.


Критерії прийняття завдання

Увага! Завдання повинно відповідати кожному з пунктів, інакше буде надіслане на доопрацювання.
1. Step Function створено через Terraform, з мінімум двома кроками (наприклад: ValidateData → LogMetrics);

2. Lambda-функції зберігаються у terraform/lambda/ і мають архіви .zip, які підключаються до ресурсу aws_lambda_function;

3. У main.tf створено:

IAM ролі для Lambda і Step Function
Lambda-функції
Step Function з правильною структурою;
4. GitLab CI (.gitlab-ci.yml) містить:

Етап train-model, який викликає aws stepfunctions start-execution
Використання офіційного образу AWS CLI
Передачу параметрів через -input;
5. README.md містить:

Як зібрати архіви .zip;
Як запустити terraform apply;
Як вручну перевірити Step Function через AWS Console;
Як працює GitLab CI job;
Приклад переданого JSON через CI.


Завантаження домашнього завдання

Створіть гілку у репозиторії: lesson-10;
Закомітьте всі зміни;
Завантажте .zip архів у LMS з назвою: ДЗ10_Прізвище_Імʼя.zip
Додайте посилання на гілку lesson-10.
