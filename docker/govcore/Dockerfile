FROM elixir:1.19 AS build

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      build-essential git npm curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY mix.exs mix.lock ./
ENV MIX_ENV=prod

RUN mix deps.get --only prod

COPY config config
COPY lib lib
COPY priv priv

RUN mix compile

COPY assets assets
RUN mix assets.setup
RUN mix assets.deploy

RUN mix phx.digest

RUN mix release

FROM debian:bookworm-slim AS runtime

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      libstdc++6 openssl libncurses5 locales ca-certificates && \
    rm -rf /var/lib/apt/lists/

WORKDIR /opt/app

COPY --from=build /app/_build/releases /app/_build/releases
COPY --from=build /app/rel /app/rel

RUN ln -sf /opt/app/rel/governance_core/bin/governance_core /opt/app/bin/start

RUN mkdir -p /opt/app/data

ENV PORT=4000
ENV MIX_ENV=prod
ENV DATABASE_PATH=/opt/app/data/governance_core_dev.db

EXPOSE 4000

CMD ["/opt/app/bin/start"]
