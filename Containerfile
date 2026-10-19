# Official image and package snapshot are explicit release inputs.
FROM docker.io/library/archlinux:base@sha256:363129b67b2bc6c5a634f8fb4961a7e2eba213a2ec075d159127b1260290a722 AS builder
ARG ARCH_SNAPSHOT=2026/10/13
RUN printf 'Server = https://archive.archlinux.org/repos/%s/$repo/os/$arch\n' "$ARCH_SNAPSHOT" > /etc/pacman.d/mirrorlist \
    && pacman -Syyuu --noconfirm --needed archlinux-keyring patchelf binutils python gcc pkgconf wpewebkit \
    && pkg-config --exists wpe-webkit-2.0 wpe-platform-headless-2.0
COPY config /src/config
COPY scripts /src/scripts
COPY tests /src/tests
RUN /src/scripts/build.sh
# The test container has no builder userspace. Docker supplies proc/dev normally.
RUN mkdir -p /testroot/usr /testroot/proc /testroot/dev /testroot/tmp /testroot/run/pizza /testroot/etc \
    && ln -s /opt/pizza/bundle/lib /testroot/usr/lib \
    && ln -s /opt/pizza/bundle/share /testroot/usr/share \
    && ln -s /opt/pizza/bundle/bin /testroot/bin \
    && ln -s /opt/pizza/bundle/lib /testroot/lib \
    && ln -s /opt/pizza/bundle/lib /testroot/lib64
FROM scratch
COPY --from=builder /testroot/ /
COPY --from=builder /opt/pizza/bundle /opt/pizza/bundle
COPY --from=builder /out /out
COPY scripts/test.sh /test.sh
ENV PATH=/opt/pizza/bundle/bin
CMD ["/bin/bash", "/test.sh"]
