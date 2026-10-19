# Official image and package snapshot are explicit release inputs.
FROM docker.io/library/archlinux:base@sha256:363129b67b2bc6c5a634f8fb4961a7e2eba213a2ec075d159127b1260290a722
ARG ARCH_SNAPSHOT=2026/10/13
RUN printf 'Server = https://archive.archlinux.org/repos/%s/$repo/os/$arch\n' "$ARCH_SNAPSHOT" > /etc/pacman.d/mirrorlist \
    && pacman -Syyuu --noconfirm --needed archlinux-keyring patchelf binutils python gcc pkgconf wpewebkit \
    && pkg-config --exists wpe-webkit-2.0 wpe-platform-headless-2.0
COPY config /src/config
COPY scripts /src/scripts
COPY tests /src/tests
RUN /src/scripts/build.sh
CMD ["/src/scripts/test.sh", "/opt/pizza/bundle"]
