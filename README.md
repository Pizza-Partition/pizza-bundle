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
Launch executables with the runtime root as the working directory so relative PT_INTERP resolves to `lib/ld-linux-x86-64.so.2`. The runtime can be moved to any directory. Pizza adds its own executables and panel separately. Image modules come from the pinned kernel package, never the build host.

To update dependencies, change `ARCH_SNAPSHOT` in Containerfile and, when needed,
the official base-image digest and `config/packages.txt`, then test and tag a new release.
Upstream software retains its own license, preserved under `share/licenses`.

The kernel package URL and SHA-256 are fixed in `config/kernel.json`; the Arch package signature is verified before extraction. `depmod` builds the matching module indexes. A QEMU boot test must print the exact kernel release before publication. The separate `pizza-kernel-x86_64.tar.gz` contains `vmlinuz`, `kernel.json` and `lib/modules/<release>`. Firmware is hardware-specific and is not bundled yet. Both release archives receive provenance attestations.


The primary image contract is now `pizza-base-x86_64.img`, `vmlinuz` and `base.json`.
Dracut assembles the base with the portable runtime, selected kernel modules,
module load order and WPE resource aliases. It deliberately has no `/init` or Pizza
application. `/opt/pizza/bundle` is the image layout, not an ELF install prefix;
the same runtime is still tested at two other locations.

Pizza verifies these three assets against their locked digests and provenance,
then appends a newc application layer containing `/init`, its executable and UI.
It does not extract, repatch or rebuild the base. The producer boots the base
with a separate static test init, loads its modules and executes its dynamic ABI
probe under QEMU. Failed relocation, WPE, module or base boot tests block releases.
The raw runtime and full kernel archives remain available for development.

The current driver profile covers virtio, NVMe, AHCI, ext4 and a diagnostic dummy
interface. It contains no hardware firmware. Additional hardware profiles belong
here, rather than in Pizza. A future UEFI image can assemble the combined
initramfs into a UKI and sign that final UKI, then use systemd-boot; this release
is an initramfs base, not a bootable ISO or a signed UKI.
