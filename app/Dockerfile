FROM python:3.12-alpine AS builder

WORKDIR /app
COPY app/requirements.txt .

RUN apk add --no-cache --virtual .build-deps gcc musl-dev libffi-dev openssl-dev \
    && mkdir -p /root/.local \
    && pip install --user --no-cache-dir -r requirements.txt \
    && apk del .build-deps

FROM python:3.12-alpine

RUN addgroup -g 1001 appgroup && \
    adduser -u 1001 -G appgroup -D -s /bin/sh appuser && \
    mkdir -p /home/appuser/.local

USER appuser
WORKDIR /app

COPY --chown=appuser:appgroup --from=builder /root/.local /home/appuser/.local
COPY --chown=appuser:appgroup app/src/ ./src/

ENV PATH="/home/appuser/.local/bin:$PATH"
ENV PYTHONUNBUFFERED=1

EXPOSE 8000
HEALTHCHECK --interval=15s --timeout=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

CMD ["uvicorn", "src.app:app", "--host", "0.0.0.0", "--port", "8000"]