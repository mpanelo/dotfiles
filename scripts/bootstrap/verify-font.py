"""Check the configured Alacritty family using read-only macOS font discovery."""
import ctypes
from pathlib import Path
import sys
import tomllib


def available_families():
    if sys.platform != "darwin":
        raise RuntimeError("Font discovery requires macOS.")
    cf = ctypes.CDLL("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")
    ct = ctypes.CDLL("/System/Library/Frameworks/CoreText.framework/CoreText")
    pointer = ctypes.c_void_p
    index = ctypes.c_long
    signatures = {
        "CFArrayGetCount": ([pointer], index),
        "CFArrayGetValueAtIndex": ([pointer, index], pointer),
        "CFStringGetLength": ([pointer], index),
        "CFStringGetCString": ([pointer, pointer, index, ctypes.c_uint32], ctypes.c_bool),
        "CFRelease": ([pointer], None),
    }
    for name, (arguments, result) in signatures.items():
        function = getattr(cf, name)
        function.argtypes = arguments
        function.restype = result
    ct.CTFontManagerCopyAvailableFontFamilyNames.argtypes = []
    ct.CTFontManagerCopyAvailableFontFamilyNames.restype = pointer
    families = ct.CTFontManagerCopyAvailableFontFamilyNames()
    if not families:
        raise RuntimeError("CoreText could not enumerate available font families.")
    try:
        names = set()
        for position in range(cf.CFArrayGetCount(families)):
            value = cf.CFArrayGetValueAtIndex(families, position)
            buffer = ctypes.create_string_buffer(4 * cf.CFStringGetLength(value) + 1)
            if not cf.CFStringGetCString(value, buffer, len(buffer), 0x08000100):
                raise RuntimeError("CoreText could not decode a font family name.")
            names.add(buffer.value.decode("utf-8"))
        return names
    finally:
        cf.CFRelease(families)


def check_font(config_path):
    with Path(config_path).open("rb") as config:
        settings = tomllib.load(config)
    family = settings.get("font", {}).get("normal", {}).get("family")
    if not isinstance(family, str) or not family:
        raise RuntimeError("Alacritty must declare font.normal.family.")
    families = available_families()
    if family not in families:
        related = ", ".join(sorted(name for name in families if "JetBrains" in name)) or "none"
        raise RuntimeError(
            f"Font family {family!r} is not visible to macOS CoreText.\n"
            f"Visible JetBrains families: {related}.\n"
            "Fully quit Alacritty and log out or restart, then rerun bootstrap.\n"
            "If it persists, inspect the font in Font Book; do not force a reinstall."
        )
    print(f"Font available to macOS: {family}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("Usage: verify-font.py ALACRITTY_CONFIG")
    try:
        check_font(sys.argv[1])
    except (OSError, RuntimeError, ValueError) as error:
        sys.exit(f"dotfiles: {error}")
