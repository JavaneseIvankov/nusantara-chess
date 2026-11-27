#!/usr/bin/env python3
"""Build the two portable desktop packages with pinned upstream binaries."""

import argparse
import hashlib
import shutil
import subprocess
import tarfile
import tempfile
import zipfile
from pathlib import Path


PROJECT = Path(__file__).resolve().parents[1]
STOCKFISH_RELEASE = "https://github.com/official-stockfish/Stockfish/releases/tag/sf_19"
STOCKFISH_DOWNLOADS = "https://github.com/official-stockfish/Stockfish/releases/download/sf_19/"
GODOT_SOURCES = "https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/"
PACKAGES = {
    "Windows": (
        "Windows Desktop", "NusantaraChess.exe", "stockfish.exe",
        "stockfish-windows-x86-64-universal.zip", "sf-win.zip",
        "3c8bf1f9ea66a09350a40df4f632288285ac206d99f33ab5842c408fc30b48a7",
    ),
    "Linux": (
        "Linux", "NusantaraChess.x86_64", "stockfish",
        "stockfish-linux-x86-64-universal.tar.gz", "sf-linux.tar.gz",
        "9defc0d4e55d49c65a6d042f3e571a39fcea499ade6dbe741b53b8c65e03611f",
    ),
}


def fetch(url, path, digest=None):
    if not path.is_file():
        partial = path.with_suffix(path.suffix + ".part")
        subprocess.run(["curl", "-fsSL", "--retry", "3", "-o", str(partial), url], check=True)
        partial.replace(path)
    if digest:
        with path.open("rb") as stream:
            actual = hashlib.file_digest(stream, "sha256").hexdigest()
        if actual != digest:
            raise SystemExit(f"Checksum mismatch. Re-download {path}")


def extract_engine(archive, upstream_name, destination, licenses):
    binary_name = upstream_name.removesuffix(".tar.gz").removesuffix(".zip")
    if archive.suffix == ".zip":
        binary_name += ".exe"
        with zipfile.ZipFile(archive) as package:
            with package.open(f"stockfish/{binary_name}") as stream, destination.open("wb") as binary:
                shutil.copyfileobj(stream, binary)
            for name in ["Copying.txt", "AUTHORS", "README.md"]:
                (licenses / f"Stockfish-{name}").write_bytes(package.read(f"stockfish/{name}"))
    else:
        with tarfile.open(archive) as package:
            selected = {f"stockfish/{name}" for name in [binary_name, "Copying.txt", "AUTHORS", "README.md"]}
            for entry in package:
                if entry.name not in selected:
                    continue
                source = package.extractfile(entry)
                assert source is not None
                name = Path(entry.name).name
                target = destination if name == binary_name else licenses / f"Stockfish-{name}"
                with source, target.open("wb") as output:
                    shutil.copyfileobj(source, output)
    destination.chmod(0o755)


def run_godot(godot, *args):
    result = subprocess.run([str(godot), "--headless", "--path", str(PROJECT), *args],
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    if result.returncode or any(line.startswith(("ERROR:", "SCRIPT ERROR:")) for line in result.stdout.splitlines()):
        print(result.stdout)
        raise SystemExit(result.returncode or 1)


def package(system, cache, target, godot):
    preset, launcher, binary, upstream, cache_name, digest = PACKAGES[system]
    release = f"NusantaraChess-{system}-x64"
    download = cache / cache_name
    fetch(STOCKFISH_DOWNLOADS + upstream, download, digest)
    with tempfile.TemporaryDirectory(prefix="nusantara-release-", dir=cache) as temporary:
        root = Path(temporary) / release
        (root / "engine").mkdir(parents=True)
        licenses = root / "licenses"
        licenses.mkdir()
        extract_engine(download, upstream, root / "engine" / binary, licenses)
        for name in ["LICENSE.txt", "COPYRIGHT.txt"]:
            saved = cache / ("Godot-" + name)
            fetch(GODOT_SOURCES + name, saved)
            shutil.copyfile(saved, licenses / saved.name)
        for license_path in (PROJECT / "assets/ui/fonts").glob("*-OFL.txt"):
            shutil.copyfile(license_path, licenses / license_path.name)
        (licenses / "Stockfish-source.txt").write_text(
            f"Stockfish 19, unmodified official binary\n\n"
            f"Exact release with corresponding source files and build scripts:\n{STOCKFISH_RELEASE}\n"
            f"Exact archive: {STOCKFISH_DOWNLOADS}{upstream}\nSHA-256: {digest}\n"
            f"Source tag: https://github.com/official-stockfish/Stockfish/tree/sf_19\n",
            encoding="utf-8",
        )
        (root / "BACA-SAYA.txt").write_text(
            f"NUSANTARA CHESS | TAKHTA DELAPAN PETAK\n\n"
            f"1. Ekstrak seluruh ZIP ke satu folder.\n"
            f"2. Jalankan {launcher}. Biarkan folder engine berada di sampingnya.\n"
            + ("   Jika izin eksekusi hilang saat ekstraksi, jalankan:\n"
               "   chmod +x NusantaraChess.x86_64 engine/stockfish\n" if system == "Linux" else "")
            + "3. Pilih Lawan Bot, faksi, dan tingkat kesulitan. Atau pilih Dua Pemain Lokal.\n\n"
            "Game berjalan offline. Klik bidak lalu petak tujuan. Gunakan klik kanan dan geser\n"
            "untuk memutar kamera, atau gulir untuk mengatur jarak.\n\n"
            "Ilustrasi 2D berasal dari tim Nusantara Chess. Lihat folder licenses untuk\n"
            "lisensi Godot, Stockfish, dan kedua font.\n",
            encoding="utf-8",
        )
        run_godot(godot, "--export-release", preset, str(root / launcher))
        if system == "Linux":
            (root / launcher).chmod(0o755)
        final_zip = target / (release + ".zip")
        partial = target / (release + ".zip.part")
        with zipfile.ZipFile(partial, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=5) as bundle:
            for path in sorted(root.rglob("*")):
                if path.is_file():
                    bundle.write(path, path.relative_to(root.parent))
        with zipfile.ZipFile(partial) as bundle:
            if bundle.testzip():
                raise SystemExit(f"Invalid ZIP: {partial}")
        partial.replace(final_zip)
        print(final_zip, flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True, help="Godot 4.7.2 standard editor binary")
    parser.add_argument("--cache", type=Path, required=True, help="Directory for upstream archives and staging")
    parser.add_argument("--output", type=Path, required=True, help="Directory for the two finished ZIPs")
    options = parser.parse_args()
    godot, cache, target = (path.resolve() for path in (options.godot, options.cache, options.output))
    version = subprocess.check_output([str(godot), "--version"], text=True)
    if not version.startswith("4.7.2.stable."):
        raise SystemExit("Use the Godot 4.7.2 stable editor and matching export templates.")
    cache.mkdir(parents=True, exist_ok=True)
    target.mkdir(parents=True, exist_ok=True)
    run_godot(godot, "--editor", "--import")
    for system in PACKAGES:
        package(system, cache, target, godot)


if __name__ == "__main__":
    main()
