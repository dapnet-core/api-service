FROM elixir:latest

COPY . /app

WORKDIR /app

ARG POSTGRES_PASSWORD
ENV POSTGRES_PASSWORD=$POSTGRES_PASSWORD

RUN mix local.hex --force
RUN mix local.rebar --force
RUN mix deps.get

CMD ["./run.sh"]
