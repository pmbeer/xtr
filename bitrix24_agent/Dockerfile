FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY b24agent ./b24agent
COPY run.py ./

# Данные (SQLite и файлы отчётов) выносятся в том, чтобы жили дольше контейнера.
RUN mkdir -p /app/data && useradd --create-home --uid 1000 agent \
    && chown -R agent:agent /app
USER agent

VOLUME ["/app/data"]

CMD ["python", "run.py"]
