FROM python:3.12-slim-bookworm AS build

WORKDIR /hello-world


COPY app ./app
COPY requirements.txt .

RUN python3 -m pip install --no-cache-dir -r requirements.txt

CMD ["/bin/bash", "-c", "opentelemetry-instrument fastapi run /hello-world/app/main.py"]
