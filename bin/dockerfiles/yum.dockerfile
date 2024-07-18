ARG VENDOR=oraclelinux
ARG RELEASE=8.10
FROM ${VENDOR}:${RELEASE}

RUN yum install -y git bison mpfr-devel gmp-devel libmpc-devel zlib-devel glibc-devel gcc





