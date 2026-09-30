SUMMARY = "Cryptographic library for Python (Cryptodome namespace, no conflict with pycrypto)"
DESCRIPTION = "PyCryptodomex is the standalone, namespace-safe variant of PyCryptodome, \
 importable as Cryptodome instead of Crypto so it can coexist with a system pycrypto install."
HOMEPAGE = "http://www.pycryptodome.org"
LICENSE = "PD & BSD-2-Clause"
LIC_FILES_CHKSUM = "file://LICENSE.rst;md5=6dc0e2a13d2f25d6f123c434b761faba"

SRC_URI[md5sum] = "08bc8fbbcd6060c06f1f10e2dc18b834"
SRC_URI[sha256sum] = "7b5b7c5896f8172ea0beb283f7f9428e0ab88ec248ce0a5b8c98d73e26267d51"

inherit pypi setuptools3

BBCLASSEXTEND = "native nativesdk"
