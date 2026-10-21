# Official image and package snapshot are explicit release inputs.
FROM docker.io/library/archlinux:base@sha256:363129b67b2bc6c5a634f8fb4961a7e2eba213a2ec075d159127b1260290a722 AS builder
ARG ARCH_SNAPSHOT=2026/10/13
RUN printf 'Server = https://archive.archlinux.org/repos/%s/$repo/os/$arch\n' "$ARCH_SNAPSHOT" > /etc/pacman.d/mirrorlist \
    && pacman -Syyuu --noconfirm --needed archlinux-keyring patchelf binutils python gcc pkgconf curl libarchive kmod cpio zstd xz gzip
COPY config /src/config
COPY scripts /src/scripts
COPY tests /src/tests
RUN /src/scripts/build.sh && /src/scripts/kernel.sh && cd /src && tests/modules.sh && scripts/base.sh
# Use the same isolated test root as the direct Arch CI build.
RUN /src/scripts/prepare-test-root.sh
FROM scratch
COPY --from=builder /testroot/ /
COPY --from=builder /out /out
COPY --from=builder /kernel /kernel
COPY --from=builder /kernel-smoke.cpio.gz /kernel-smoke.cpio.gz
ENV PATH=/relocated/runtime/bin
WORKDIR /relocated/runtime
CMD ["bin/bash", "/test.sh"]
