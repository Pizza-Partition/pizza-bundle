# pizza-bundle

Third-party userspace for [Pizza](https://github.com/Pizza-Partition/pizza).
This repository contains no Pizza application code. It also publishes pinned Linux 7.2.11 (Arch release 7.2.11-arch1-1) with its matching modules. It publishes a portable runtime for x86_64 Linux.

`pacman` resolves and verifies signed packages from a dated Arch Linux snapshot.
The complete runtime libraries, plugins, resources and licenses are kept together.
`patchelf` sets relative PT_INTERP and $ORIGIN-based RUNPATHs; GNU tar creates the archive. There is
no custom package resolver, ELF writer, dependency collector or per-file manifest.

```sh
docker build -f Containerfile -t pizza-runtime-builder .
docker run --rm --network none --shm-size 256m pizza-runtime-builder
container=$(docker create pizza-runtime-builder)
docker cp "$container:/out/." dist/
docker rm "$container"
```

The isolated scratch-container test checks loader/libc startup, WPE/EGL/GBM loading and a real
WebKit WebProcess JavaScript/native reply round trip. It cannot fall back to the
builder's libraries. It moves the runtime to two different directories and repeats both ABI and real WPE tests. The test disables WebKit sandboxing only inside the CI test. No extra container capabilities or security-policy overrides are required.
DRM hardware, sandbox enforcement, RAM budgets and old-kernel compatibility need
separate acceptance tests; this release does not claim those passed.

Pushing a `v*` tag builds and tests the runtime, then attests the final archive
with GitHub's Sigstore-backed artifact attestations and publishes a GitHub Release.
Failed tests prevent publication. Main/PR builds test without publishing.
Each release includes the archive, SHA256SUMS, package versions and attestation.

Consumers must pin the archive digest, source commit, tag and this repository's
`release.yml` workflow, and verify the attestation before extraction. `runtime.json`
is a small format/architecture/interface contract, not a content security audit.
Launch executables with the runtime root as the working directory so relative PT_INTERP resolves to `lib/ld-linux-x86-64.so.2`. The runtime can be moved to any directory. Pizza adds its own executables
and panel separately; kernel modules always come from the target host kernel.

To update dependencies, change `ARCH_SNAPSHOT` in Containerfile and, when needed,
the official base-image digest and `config/packages.txt`, then test and tag a new release.
Upstream software retains its own license, preserved under `share/licenses`.

The kernel package URL and SHA-256 are fixed in `config/kernel.json`; the Arch package signature is verified before extraction. `depmod` builds the matching module indexes. A QEMU boot test must print the exact kernel release before publication. The separate `pizza-kernel-x86_64.tar.gz` contains `vmlinuz`, `kernel.json` and `lib/modules/<release>`. Firmware is hardware-specific and is not bundled yet. Both release archives receive provenance attestations.
