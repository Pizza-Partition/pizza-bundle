# pizza-bundle

Third-party userspace for [Pizza](https://github.com/Pizza-Partition/pizza).
This repository contains no Pizza application code.

The sibling `pizza` and `pizza-maint` Zig builds use Zig's `Coff.zig` linker on
Windows and `Elf2.zig` on Linux, with incremental compilation enabled. Their
`zig build dev` entry point runs `zig build -fincremental --watch` (additional
build arguments follow `--`). This repository packages upstream Linux binaries
with pacman and shell scripts and uses the pinned system C compiler for its test
probes; it has no Zig build graph. Zig linker and incremental/watch flags therefore
do not apply here. Use the container build below for bundle changes.

It also publishes pinned Linux 7.2.11 (Arch release 7.2.11-arch1-1) with its matching modules. It publishes a portable runtime for x86_64 Linux.

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
It moves the runtime to two different directories and repeats the ABI and recovery-tool checks.
The runtime is a filesystem-rescue subset of SystemRescue's package inventory, including
Bash, Vim, Nano, offline manuals, partition/filesystem tools, LVM/RAID/LUKS tools,
data recovery, hardware diagnostics and network transfer. Desktop applications,
browsers and multimedia are not selected. Signed package dependencies are resolved by pacman.
Real DRM output and old-kernel compatibility remain separate acceptance work.

Pushing a `v*` tag builds and tests the runtime, then attests the final archive
with GitHub's Sigstore-backed artifact attestations and publishes a GitHub Release.
Failed tests prevent publication. Main/PR builds test without publishing.
Each release includes the archive, SHA256SUMS, package versions and attestation.

Consumers must pin the archive digest, source commit, tag and this repository's
`release.yml` workflow, and verify the attestation before extraction. `runtime.json`
is a small format/architecture/interface contract, not a content security audit.
Launch executables from the portable runtime with its root as the working directory so relative PT_INTERP resolves to `lib/ld-linux-x86-64.so.2`. The portable runtime can be moved to any directory.
The installed base image gives its copy of these executables the conventional absolute
`/lib64/ld-linux-x86-64.so.2` interpreter, allowing rescue-shell commands to run after
changing directories. Pizza adds its own executables separately. Image modules come from the pinned kernel package, never the build host.

To update dependencies, change `ARCH_SNAPSHOT` in both `Containerfile` and
`.github/workflows/release.yml` and, when needed, update the official base-image
digest in both files, then test and tag a new release.
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
Consumers must pin a published release of this profile before assembling a new application image; old browser-profile
release assets are incompatible and must not be relabeled.

## SystemRescue filesystem-rescue subset

The checked-in upstream baseline is the official [SystemRescue 13.02 amd64 package
inventory](https://www.system-rescue.org/Detailed-packages-list/), normalized into
`config/systemrescue/packages.tsv`. Its source URL, release and digest are recorded
in `config/systemrescue/source.json`. `config/packages.txt` selects the rescue subset
by function. Both the selected packages and pacman's complete resolved dependency
closure must belong to the upstream inventory; the build fails on unexpected packages.

This is a package-set derivative, not a repackaged SystemRescue ISO. Binary versions
come from this project's pinned Arch snapshot and may differ from the reference
versions in the upstream inventory. `share/pizza/rescue.json` records both the source
baseline and actual installed package versions. Updating the baseline is an explicit
source change; builds never fetch a moving upstream list.

Use Bash for the full environment. The package-provided static
`bin/busybox` is the last-resort shell if the dynamic environment cannot
start. Vim and Nano are included; GNU Emacs is outside this upstream inventory and
is deliberately not added. Man pages, terminfo, editor runtime resources and licenses
are retained. `zerofree`, which is not available in the pinned official Arch repositories,
is not selected; no unsigned auxiliary repository is enabled as a fallback.

Filesystem tools include btrfs-progs, e2fsprogs, xfsprogs, dosfstools, fatresize,
exfatprogs, ntfs-3g/ntfsprogs, f2fs-tools, nilfs-utils, udftools, mtools and squashfs-tools.
They are ordinary upstream CLI tools for manual recovery. Pizza's native execution
engine remains a separate consumer concern. The legacy libblockdev plugin bridge
is no longer a runtime input.

`config/rescue-tools.json` and `config/filesystem-tools.json` define required commands.
Scratch tests start them after both relocations, check offline manuals and terminfo,
edit a file with Vim and execute the static fallback shell. They also format and
check disposable regular-file ext4/FAT images; no real block devices are accessed.
The same smoke script runs during the base-image QEMU boot test. The explicit kernel
profile adds loop, FUSE, device-mapper and MD RAID support needed by manual recovery.

Pizza keeps power orchestration in its PID 1. The rescue environment retains the
operator's normal root privileges and kernel capability checks; it does not implement
a command allowlist or remove power privileges. The real `reboot`, `poweroff` and
`halt` commands are symlinks to the upstream static BusyBox applets. Their normal
mode uses BusyBox's standard init signals; `-f` directly calls the kernel. The
consumer's PID 1 handles the standard signals and controls shutdown. No shell
functions or private Pizza power commands are installed.

## Architecture and delivery status

The producer owns signed package inputs, third-party ELF relocation, the pinned kernel/module pair,
explicit hardware profiles and base-image tests. Pizza owns its static init, ordinary maintenance
application, protected handoff, journal, TUI and eventual native renderer. The consumer verifies the
published assets and appends its own layer; it does not collect dependencies from the host.

Local validation of the SystemRescue filesystem-rescue subset passed:

- 7 policy tests, including changed upstream inventories, unexpected packages/dependencies and missing tools.
- 67 selected packages and a 172-package resolved closure, all present in the 894-package upstream baseline.
- 105 command starts after each of two relocations, offline man/terminfo lookup, Vim editing and the static shell.
- ext4/FAT creation and checking on disposable regular-file images, in both scratch containers and QEMU.
- Linux 7.2.11 QEMU boot with 54 loadable modules and all 19 configured filesystems registered.
- Image commands and a child Bash/Vim invocation after changing out of the runtime directory.

The base initramfs is approximately 206 MiB compressed; the userspace tree is approximately
641 MiB unpacked. These tests do not access real disks or certify recovery on physical hardware.
The subset is a source change pending a new release; consumers retain their existing published
asset locks until that release is built, attested and published.

The [v0.4.1 release](https://github.com/Pizza-Partition/pizza-bundle/releases/tag/v0.4.1) passed the
[complete publishing workflow](https://github.com/Pizza-Partition/pizza-bundle/actions/runs/39596637458)
and includes attestation for its final assets. Consumer integration pins those actual assets and
verifies the application layer separately. Later work adds explicit Blend2D/DRM userspace inputs,
verifies cold-boot and kexec display handover, integrates real storage operations, and builds UEFI
media. No step may restore host collection as a fallback.

## Naming conventions

- Functions use `camelCase`; types and type aliases use `PascalCase`.
- Compile-time value constants use `UPPER_SNAKE_CASE`.
- Local variables and ordinary parameters use `snake_case`, including runtime-initialized Zig local `const` bindings.
- Module namespace aliases use `snake_case`; type parameters use `PascalCase`.
- Names required by external ABIs, third-party APIs, and serialized protocols retain their required spelling.
