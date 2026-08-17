# syntax=docker/dockerfile:1

FROM debian:bookworm-slim AS build

RUN apt-get update \
    && apt-get install --no-install-recommends -y build-essential ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY . .

RUN make -j"$(nproc)" portable \
    && make test

FROM python:3.12-slim-bookworm AS runtime

RUN apt-get update \
    && apt-get install --no-install-recommends -y ca-certificates curl libgomp1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/k3

COPY --from=build /src/bin/k3 /usr/local/bin/k3
COPY --from=build /src/scripts ./scripts
COPY --from=build /src/tools ./tools
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod 0755 /usr/local/bin/docker-entrypoint.sh \
    && find /opt/k3/scripts -type f -name '*.sh' -exec chmod 0755 {} +

ENV K3_MODEL_DIR=/models/checkpoint \
    K3_TRUNK_DIR=/models/trunk \
    K3_TOKENIZER_DIR=/models/checkpoint \
    K3_PRESET=laptop \
    K3_GEN=8 \
    K3_INCREMENTAL=1 \
    K3_OUT=/output/k3_run.json

VOLUME ["/models/checkpoint", "/models/trunk", "/output"]

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
