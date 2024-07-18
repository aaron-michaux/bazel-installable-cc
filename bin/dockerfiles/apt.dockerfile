ARG VENDOR=debian
ARG RELEASE=bullseye
FROM ${VENDOR}:${RELEASE}

RUN apt-get -y update \
    && apt-get -y install \
    git wget subversion automake swig python2.7-dev libedit-dev libncurses5-dev  \
    gcc-multilib python3-dev python3-pip python3-tk python3-lxml python3-six \
    libparted-dev flex sphinx-doc guile-2.2 gperf gettext expect tcl dejagnu \
    libgmp-dev libmpfr-dev libmpc-dev patchelf liblz-dev pax-utils bison flex \
    libxapian-dev lld


