FROM docker.io/library/golang:1.20.5-buster AS build

WORKDIR /workspace
ADD . /workspace

RUN apt update --yes && \
    apt install --yes build-essential && \
    make install \
      PREFIX=/usr \
      DESTDIR=/app \
      EXECUTABLE=fail2ban_exporter

FROM docker.io/library/debian:10-slim

COPY --from=build /app /

EXPOSE 9191

ENTRYPOINT [ "/usr/bin/fail2ban_exporter" ]
