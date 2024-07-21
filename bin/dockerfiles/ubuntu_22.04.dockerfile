FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get -qq -y update \
    && apt-get -y install \
    file git wget subversion automake libedit-dev libncurses5-dev swig \
    gcc-multilib python3-dev python3-pip python3-tk python3-lxml python3-six \
    libparted-dev flex sphinx-doc guile-2.2 gperf gettext expect tcl dejagnu \
    libgmp-dev libmpfr-dev libmpc-dev patchelf liblz-dev pax-utils bison flex \
    libxapian-dev lld zstd libzstd-dev libssl-dev openssl


