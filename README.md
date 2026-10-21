# pizza-bundle

Third-party userspace for [Pizza](https://github.com/Pizza-Partition/pizza).
This repository contains no Pizza application code. It also publishes pinned Linux 7.2.11 (Arch release 7.2.11-arch1-1) with its matching modules. It publishes a portable runtime for x86_64 Linux.

CI runs all steps directly in the official Arch Linux job container pinned by SHA-256
in `.github/workflows/release.yml`. Its package repository is fixed to the
`2026/10/13` Arch Linux Archive snapshot, including patchelf, compiler, QEMU and
release tools. GitHub's Ubuntu runner only hosts the job container and Docker
daemon; Ubuntu packages are not used for build or boot-test tools. A native Arch
self-hosted runner is not required.

`pacman` resolves and verifies signed packages from that dated Arch Linux snapshot.
The complete runtime libraries, plugins, resources and licenses are kept together.
`patchelf` sets relative PT_INTERP and $ORIGIN-based RUNPATHs; GNU tar creates the archive. There is
no custom package resolver, ELF writer, dependency collector or per-file manifest.

For local builds, `Containerfile` uses the same pinned Arch image and package
snapshot. CI calls the build scripts directly and builds only the scratch test
image from `tests/Containerfile`; it does not build another Arch builder image.

```sh
docker build -f Containerfile -t pizza-runtime-builder .
docker run --rm --network none --shm-size 256m pizza-runtime-builder
container=$(docker create pizza-runtime-builder)
docker cp "$container:/out/." dist/
docker rm "$container"
```

The isolated scratch-container test checks loader/libc startup and rejects mappings outside the relocated runtime.
It moves the runtime to two different directories and repeats the ABI checks. The runtime contains glibc, coreutils, bash, libblockdev-fs and the filesystem tools listed in
`config/filesystem-tools.json`, including their signed package dependencies. Browser, GPU acceleration and multimedia stacks are removed.
Real DRM output and old-kernel compatibility remain separate acceptance work.

Pushing a `v*` tag builds and tests the runtime, then attests the final archive
with GitHub's Sigstore-backed artifact attestations and publishes a GitHub Release.
Failed tests prevent publication. Main/PR builds test without publishing.
Each release includes the archive, SHA256SUMS, package versions and attestation.

Consumers must pin the archive digest, source commit, tag and this repository's
`release.yml` workflow, and verify the attestation before extraction. `runtime.json`
is a small format/architecture/interface contract, not a content security audit.
Launch executables with the runtime root as the working directory so relative PT_INTERP resolves to `lib/ld-linux-x86-64.so.2`. The runtime can be moved to any directory. Pizza adds its own executables separately. Image modules come from the pinned kernel package, never the build host.

To update dependencies, change `ARCH_SNAPSHOT` in both `Containerfile` and
`.github/workflows/release.yml` and, when needed, update the official base-image
digest in both files and `config/packages.txt`, then test and tag a new release.
The pinned snapshot supplies patchelf 0.19.2. CI logs its version and the other
build/CI tool versions. The snapshot pins their package versions; the runner's
preinstalled tools are not used.
Upstream software retains its own license, preserved under `share/licenses`.

The kernel package URL and SHA-256 are fixed in `config/kernel.json`; the Arch package signature is verified before extraction. `depmod` builds the matching module indexes. A QEMU boot test must print the exact kernel release before publication. The separate `pizza-kernel-x86_64.tar.gz` contains `vmlinuz`, the extracted image `config`, `kernel.json` and `lib/modules/<release>`. The generic profile needs no external firmware. Any driver declaring firmware makes packaging fail until a pinned hardware profile is implemented. Both release archives receive provenance attestations.

The primary image contract is now `pizza-base-x86_64.img`, `vmlinuz` and `base.json`.
`scripts/base.sh` assembles it with standard cpio/gzip from explicit package-built trees.
`scripts/modules.sh` requires a package root, output root, exact release and `config/maintenance.json`;
it resolves dependencies with kmod against only that package root and writes the uncompressed module load order.
There is no dracut, host hardware scan, fallback module root or host firmware lookup.
The base has no `/init` or Pizza application. `/opt/pizza/bundle` is the image layout, not an ELF install prefix.

Pizza verifies the three assets against locked digests and provenance, then appends its application layer.
The producer boots the base with a static test init, loads its modules, checks every configured filesystem
in `/proc/filesystems` and executes the dynamic ABI probe. Failed relocation, module or boot tests block releases.
The raw runtime and full kernel archives remain available for development.

The `cpu-maint-v1` profile covers virtio, NVMe, AHCI/SCSI, USB storage/UAS and host controllers,
USB/PS2 input, ext2/3/4, Btrfs, XFS, NTFS, NTFS3, FAT/VFAT, exFAT, F2FS, ISO9660, UDF,
SquashFS, EROFS, OverlayFS, HFS/HFS+ and NILFS2, plus NLS dependencies.
Filesystem registration is boot-tested; this does not certify every filesystem's read/write behavior.
Production journal support is a separate consumer policy.

`simpledrm` is built into the pinned kernel. `scripts/extract-ikconfig` is the GPL-2.0 upstream kernel
helper from Linux 7.2.11. Build checks the actual kernel image for built-in EFI, EFI_STUB, SYSFB,
SYSFB_SIMPLEFB, DRM and DRM_SIMPLEDRM, plus ext4's ext2 compatibility. No separate GPU firmware is needed.
Native Blend2D/DRM userspace will be added with the future consumer implementation; this release retains TUI/console only.
The Linux 7.1+ `ntfs` kernel driver and `ntfs3` are both included; NTFS-3G is a separate userspace FUSE implementation.
[NTFS driver documentation](https://www.kernel.org/doc/html/latest/filesystems/ntfs.html).

Additional hardware profiles and pinned firmware sources belong here. A future UEFI image can assemble
the combined initramfs into a UKI and sign that final UKI, then use systemd-boot. Firmware framebuffer
handover across kexec still requires real hardware verification; this release is an initramfs base.
Consumers must publish and pin this new profile before assembling a new application image; old browser-profile
release assets are incompatible and must not be relabeled.

Filesystem tool inputs are btrfs-progs, e2fsprogs, xfsprogs, dosfstools, exfatprogs,
ntfsprogs, f2fs-tools, nilfs-utils, udftools and libblockdev-fs (which supplies vfat-resize).
The command inventory is checked before packing. Scratch tests execute each command's help entry,
load the real filesystem plugin and check its supported-operation dependencies after both relocations.
These checks do not format, repair or resize devices. Package-owned `/etc` configuration and conventional
command/interpreter aliases are provided in the RAM image for shell-based helpers.
NTFS utilities come from NTFS-3G's ntfsprogs split package; the userspace NTFS-3G mount driver is not required by this tool list.

## Architecture and delivery status

The producer owns signed package inputs, third-party ELF relocation, the pinned kernel/module pair,
explicit hardware profiles and base-image tests. Pizza owns its static init, ordinary maintenance
application, protected handoff, journal, TUI and eventual native renderer. The consumer verifies the
published assets and appends its own layer; it does not collect dependencies from the host.

Local validation of the current source profile passed two relocations with 40 command starts and
11 filesystem-plugin technology checks, then booted the base with 27 loadable modules and all
19 configured filesystems registered. These are base/runtime checks, not real filesystem mutation,
visible DRM output, a completed consumer transition, or evidence of a new published release.

The next delivery gate is a tested producer release and attestation, followed by Pizza updating its
old v0.3.1 lock to the actual new assets. Pizza must also replace the removed bubblewrap command in
its maintenance supervisor test before rerunning the complete application image tests. Later work
adds explicit Blend2D/DRM userspace inputs, verifies cold-boot and kexec display handover, integrates
real storage operations, and builds UEFI media. No step may restore host collection as a fallback.
