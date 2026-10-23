#!/usr/bin/env bash
set -euo pipefail

# Prepares trusted, downloaded inputs for build-repository-offline.sh on the
# networked preparation guest. Nothing from the repository is compiled here.
if [ "$(id -u)" -ne 0 ]; then
  echo 'Run trusted repository-input preparation as root' >&2
  exit 2
fi
if [ "$#" -ne 2 ]; then
  echo 'Usage: sudo bash prepare-repository-inputs.sh SOURCE_ARCHIVE LABEL' >&2
  exit 2
fi
source_archive=$(realpath "$1")
label=$2
case "$label" in
  *[!A-Za-z0-9._-]* | '' | .*) echo "Unsafe label: $label" >&2; exit 2 ;;
esac
scripts="$(cd "$(dirname "$0")" && pwd -P)"
rust_version=1.99.0
rust=/opt/cairn-toolchains/rust-$rust_version
rust_key=108F66205EAEB0AAA8DD5E1C85AB96E6FA1BE5FE
ubique_tag=v1.3.2
ubique_commit=0a901a3da37fd9d8cc71f76613e4183306ee811a
ubique=/opt/cairn-binding-seeds/ubique-1.3.2
inputs=/opt/cairn-binding-seeds/repository-inputs/$label
jdk21=/usr/lib/jvm/java-21-openjdk-amd64
umask 022
test ! -e "$inputs"

work=$(mktemp -d /var/tmp/cairn-repository-prep.XXXXXXXX)
chmod 0711 "$work"
cleanup() { rm -rf -- "$work"; }
trap cleanup EXIT

if [ ! -e "$rust" ]; then
  export GNUPGHOME="$work/gnupg"
  install -d -m 0700 "$GNUPGHOME"
  curl -fsSL --proto '=https' --tlsv1.2 https://static.rust-lang.org/rust-key.gpg.ascii \
    -o "$work/rust-key.asc"
  gpg --batch --quiet --import "$work/rust-key.asc"
  staging="$work/rust-install"
  for package in rust-$rust_version-x86_64-unknown-linux-gnu \
    rust-std-$rust_version-x86_64-linux-android \
    rust-std-$rust_version-aarch64-linux-android \
    rust-std-$rust_version-armv7-linux-androideabi; do
    for suffix in tar.xz tar.xz.sha256 tar.xz.asc; do
      curl -fsSL --proto '=https' --tlsv1.2 \
        "https://static.rust-lang.org/dist/$package.$suffix" -o "$work/$package.$suffix"
    done
    (cd "$work" && sha256sum --check "$package.tar.xz.sha256")
    gpg --batch --status-fd 1 --verify "$work/$package.tar.xz.asc" "$work/$package.tar.xz" \
      2>/dev/null | grep -Eq "^\[GNUPG:\] VALIDSIG .* $rust_key\$"
    tar -xJf "$work/$package.tar.xz" -C "$work"
    components=()
    if [ "${package#rust-std-}" = "$package" ]; then
      components=(--components=rustc,cargo,rust-std-x86_64-unknown-linux-gnu)
    fi
    "$work/$package/install.sh" --prefix="$staging" --disable-ldconfig "${components[@]}" >/dev/null
  done
  chown -R root:root "$staging"
  chmod -R go-w "$staging"
  mv -T "$staging" "$rust"
fi
test "$("$rust/bin/rustc" --version | cut -d' ' -f2)" = "$rust_version"
for target in x86_64-linux-android aarch64-linux-android armv7-linux-androideabi; do
  test -d "$rust/lib/rustlib/$target/lib"
done
echo "PASS: signed Rust $rust_version with Android standard libraries"

if [ ! -e "$ubique" ]; then
  git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$ubique_tag" \
    https://github.com/UbiqueInnovation/uniffi-kotlin-multiplatform-bindings "$work/ubique"
  test "$(git -C "$work/ubique" rev-parse HEAD)" = "$ubique_commit"
  rm -rf "$work/ubique/.git"
  chown -R root:root "$work/ubique"
  chmod -R a-w "$work/ubique"
  mv -T "$work/ubique" "$ubique"
fi
test -f "$ubique/bindgen/Cargo.toml"
echo "PASS: Ubique generator source $ubique_tag ($ubique_commit)"

install -d -o cairn-build -g cairn-build -m 0700 \
  "$work/source" "$work/home" "$work/cargo" "$work/gradle-home"
install -o root -g root -m 0644 "$scripts/resolve-repository-inputs.gradle" "$work/resolve.gradle"
runuser -u cairn-build -- tar -xzf - -C "$work/source" < "$source_archive"
as_builder() {
  runuser -u cairn-build -- /usr/bin/env -i \
    PATH="$rust/bin:/usr/bin:/bin" \
    HOME="$work/home" TMPDIR="$work/home" LANG=C.UTF-8 \
    JAVA_HOME=/opt/cairn-toolchains/jdk-25.0.4.1 \
    ANDROID_HOME=/opt/cairn-toolchains/android-sdk \
    ANDROID_USER_HOME="$work/home/android" \
    CARGO_HOME="$work/cargo" CARGO_TARGET_DIR="$work/cargo-target" \
    GRADLE_USER_HOME="$work/gradle-home" "$@"
}
as_builder cargo fetch --locked --manifest-path "$work/source/core/Cargo.toml"
as_builder cargo fetch --locked --manifest-path "$ubique/Cargo.toml"
as_builder CARGO_NET_OFFLINE=true /opt/cairn-toolchains/gradle-9.7.0/bin/gradle \
  -p "$work/source" --no-daemon --console=plain \
  -Pcairn.uniffi.bindgen="$ubique/bindgen" \
  -Porg.gradle.java.installations.paths="$jdk21" \
  -PandroidAbis=x86_64,arm64-v8a \
  --init-script "$work/resolve.gradle" cairnResolveRepositoryInputs
test ! -e "$work/cargo-target"
echo 'PASS: network-enabled dependency resolution; no Cargo compilation output'

staging="$work/inputs"
canonical="$staging/canonical-inputs"
install -d -m 0755 "$canonical/cargo" "$canonical/gradle"
cp -a "$work/cargo/registry" "$canonical/cargo/registry"
cp -a "$work/gradle-home/caches/modules-2/files-2.1" "$canonical/gradle/files-2.1"
tar -czf "$staging/gradle-metadata.tar.gz" -C "$work/gradle-home" \
  --exclude=caches/modules-2/files-2.1 caches/modules-2
install -m 0644 "$source_archive" "$staging/prepared-source.tar.gz"
chown -R root:root "$staging"
(cd "$canonical" &&
  LC_ALL=C find cargo gradle -type f -print0 |
  LC_ALL=C sort -z | xargs -0 sha256sum > SHA256SUMS)
(cd "$staging" && sha256sum gradle-metadata.tar.gz prepared-source.tar.gz > SHA256SUMS)
chmod -R a-w "$staging"
install -d -m 0755 "$(dirname "$inputs")"
mv -T "$staging" "$inputs"
echo "PASS: root-owned read-only repository inputs at $inputs"
