ARG VENDOR=oraclelinux
ARG RELEASE=8.10
FROM ${VENDOR}:${RELEASE}

#     dejagnu lsb_release
RUN yum install -y \
    autoconf automake make gettext libtool \
    bash expect guile git bison flex patch pkgconfig tar wget expect check zstd  \
    mpfr-devel gmp-devel libmpc-devel zlib-devel glibc-devel libzstd-devel \
    python3-pip python3-lxml python3-six \
    binutils gcc gcc-c++ lld \
    openssl-devel openssl-libs
      

