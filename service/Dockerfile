

# Stage 1: Build dependencies
FROM python:3.12.10-slim-bookworm AS builder

WORKDIR /build

COPY requirements.txt .

RUN pip install --no-cache-dir \
    --prefix=/install \
    -r requirements.txt


# Stage 2: Runtime image
FROM python:3.12.10-slim-bookworm AS runtime

WORKDIR /app

# Copy installed dependencies from builder
COPY --from=builder /install /usr/local

# Copy application
COPY app.py .

# Runtime configuration defaults
ENV PYTHONUNBUFFERED=1

# Create non-root user
RUN groupadd --gid 10001 appgroup && \
    useradd --uid 10001 \
    --gid appgroup \
    --no-create-home \
    --shell /usr/sbin/nologin appuser

USER 10001:10001

EXPOSE 8080

CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "app:app"]
