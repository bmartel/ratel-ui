FROM golang:1.16-stretch as build

WORKDIR /ratel

RUN git clone https://github.com/dgraph-io/ratel.git .

COPY build.prod.sh ./scripts/build.prod.sh
COPY ./client ./client/build

RUN go get -u github.com/dgraph-io/ratel; exit 0 
RUN ./scripts/build.prod.sh

FROM debian:10-slim AS final
LABEL author="Brandon Martel"

RUN groupadd nobody && \
  usermod -a -G nobody nobody

COPY --from=build /ratel/build /app

WORKDIR /app

USER nobody:nobody

CMD ["./ratel"]

EXPOSE 8000

