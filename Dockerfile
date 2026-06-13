FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /srv

COPY app/requirements.txt /tmp/app-req.txt
COPY model/requirements.txt /tmp/model-req.txt
RUN pip install -r /tmp/app-req.txt -r /tmp/model-req.txt

COPY app /srv/app
COPY model /srv/model

ENV PYTHONPATH=/srv \
    PORT=8000

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]