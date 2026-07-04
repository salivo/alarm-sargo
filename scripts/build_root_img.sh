
set -euo pipefail
 
PKGS_CONF="${1:-pkgs.conf}"
IMG_NAME="${2:-rootfs.img}"
IMG_SIZE="${3:-2G}"
 
WORKDIR="$(mktemp -d /tmp/alarm-build.XXXXXX)"
ROOTFS_DIR="${WORKDIR}/rootfs"
TARBALL_URL="http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz"
TARBALL="${WORKDIR}/ArchLinuxARM-aarch64-latest.tar.gz"
 
log()  { printf '\033[1;32m[+]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[!]\033[0m %s\n' "$*" >&2; }
die()  { err "$*"; cleanup; exit 1; }
 
cleanup() {
    log "cleaning up"
    if mountpoint -q "${ROOTFS_DIR}/proc" 2>/dev/null; then
        arch-chroot "${ROOTFS_DIR}" true >/dev/null 2>&1 || true
    fi
    # arch-chroot auto-unmounts on exit, but be defensive
    for m in proc sys dev/pts dev; do
        umount -R "${ROOTFS_DIR}/${m}" 2>/dev/null || true
    done
    rm -rf "${WORKDIR}"
}
trap cleanup EXIT
 
require_root() {
    [[ $EUID -eq 0 ]] || die "run as root (needs chroot/mount/loop access)"
}
 
check_deps() {
    local deps=(arch-chroot mkfs.ext4 bsdtar wget qemu-aarch64-static)
    local missing=()
    for d in "${deps[@]}"; do
        command -v "$d" >/dev/null 2>&1 || missing+=("$d")
    done
    [[ -f /proc/sys/fs/binfmt_misc/qemu-aarch64 ]] || \
        missing+=("qemu-aarch64-binfmt (register with qemu-user-static-binfmt)")
    if ((${#missing[@]})); then
        die "missing dependencies: ${missing[*]}"
    fi
}
 
check_conf() {
    [[ -f "$PKGS_CONF" ]] || die "package list not found: $PKGS_CONF"
}
 
fetch_base() {
    log "downloading ALARM aarch64 base tarball"
    wget -q --show-progress -O "$TARBALL" "$TARBALL_URL"
    mkdir -p "$ROOTFS_DIR"
    log "extracting base tarball"
    bsdtar -xpf "$TARBALL" -C "$ROOTFS_DIR" --numeric-owner
}
 
prep_chroot() {
    log "installing qemu-aarch64-static into rootfs"
    cp -v /usr/bin/qemu-aarch64-static "${ROOTFS_DIR}/usr/bin/"
    log "seeding resolv.conf for network access inside chroot"
    cp -L /etc/resolv.conf "${ROOTFS_DIR}/etc/resolv.conf" 2>/dev/null || true
}
 
install_pkgs() {
    mapfile -t PKGS < <(grep -vE '^\s*(#|$)' "$PKGS_CONF")
    ((${#PKGS[@]})) || die "no packages listed in $PKGS_CONF"
    log "packages to install: ${PKGS[*]}"
 
    arch-chroot "$ROOTFS_DIR" pacman-key --init
    arch-chroot "$ROOTFS_DIR" pacman-key --populate archlinuxarm
    arch-chroot "$ROOTFS_DIR" pacman -Syu --noconfirm
    arch-chroot "$ROOTFS_DIR" pacman -S --noconfirm --needed "${PKGS[@]}"
    arch-chroot "$ROOTFS_DIR" pacman -Scc --noconfirm
}
 
finalize_rootfs() {
    log "removing qemu-aarch64-static from image"
    rm -f "${ROOTFS_DIR}/usr/bin/qemu-aarch64-static"
    rm -f "${ROOTFS_DIR}/etc/resolv.conf"
}
 
build_image() {
    log "creating $IMG_NAME (${IMG_SIZE}) from $ROOTFS_DIR"
    rm -f "$IMG_NAME"
    mkfs.ext4 -q -d "$ROOTFS_DIR" -r 1 -N 0 -m 0 -L rootfs -F "$IMG_NAME" "$IMG_SIZE"
    log "done: $(du -h "$IMG_NAME" | cut -f1) -> $IMG_NAME"
}
 
main() {
    require_root
    check_deps
    check_conf
    fetch_base
    prep_chroot
    install_pkgs
    finalize_rootfs
    build_image
}
 
main "$@"
