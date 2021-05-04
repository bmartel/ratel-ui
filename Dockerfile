FROM golang:1.16-stretch as build

RUN mkdir /user && \
    echo 'nobody:x:65534:65534:nobody:/:' > /user/passwd && \
    echo 'nobody:x:65534:' > /user/group

WORKDIR /ratel

RUN git clone https://github.com/dgraph-io/ratel.git .

COPY build.prod.sh /ratel/scripts/build.prod.sh
COPY ./client /ratel/client/build

RUN go get -u github.com/dgraph-io/ratel; exit 0 
RUN /ratel/scripts/build.prod.sh

FROM scratch AS final
LABEL author="Brandon Martel"

COPY --from=build /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=build /user/group /user/passwd /etc/
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=build /ratel/build/ /app/

WORKDIR /app
USER nobody:nobody
ENTRYPOINT ["/app/ratel"]

EXPOSE 8000

