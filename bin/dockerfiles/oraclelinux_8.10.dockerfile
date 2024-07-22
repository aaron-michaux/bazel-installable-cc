FROM oraclelinux:8.10

#     dejagnu lsb_release
RUN yum install -y \
    autoconf automake make gettext libtool \
    bash expect guile git bison flex patch pkgconfig tar wget expect check zstd xz \
    mpfr-devel gmp-devel libmpc-devel zlib-devel glibc-devel libzstd-devel \
    python3-pip python3-lxml python3-six \
    binutils gcc gcc-c++ lld glibc-devel glibc-devel.i686 \
    openssl-devel openssl-libs
      

