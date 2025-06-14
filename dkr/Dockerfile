ARG BASE_IMAGE

FROM ${BASE_IMAGE}

ADD build /build
RUN cat /build | /usr/local/bin/pups --stdin && rm /build

ADD init /init
ADD entry /sbin/entry

CMD [ "/sbin/entry" ]
