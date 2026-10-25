"""Make Wine's configured dlopen names resolve through the bundled runtime rpaths."""

from pathlib import Path
import re
import sys


def relocate(header: Path, prefix: Path) -> None:
    text = header.read_text()
    # Validate every input before writing anything: missing headers/libraries
    # must fail the launcher runtime build rather than silently disable TLS/fonts.
    for macro, stem in [("SONAME_LIBGNUTLS", "libgnutls"), ("SONAME_LIBFREETYPE", "libfreetype")]:
        pattern = rf'(?m)^#define {macro} "([^"]+)"$'
        matches = list(re.finditer(pattern, text))
        if len(matches) != 1:
            raise RuntimeError(f"expected one enabled {macro} in {header}")
        original = matches[0].group(1)
        name = original.removeprefix("@rpath/")
        if not re.fullmatch(re.escape(stem) + r"(?:\.[0-9]+)*\.dylib", name):
            raise RuntimeError(f"unexpected {macro}: {original}")
        if not (prefix / "lib" / name).is_file():
            raise RuntimeError(f"configured dependency missing: {prefix / 'lib' / name}")
        text = re.sub(pattern, lambda _: f'#define {macro} "@rpath/{name}"', text)
    header.write_text(text)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("usage: relocate-runtime-sonames.py <include/config.h> <dependency-prefix>")
    relocate(Path(sys.argv[1]), Path(sys.argv[2]))
