import plistlib
import re
import shlex
import subprocess
import sys
from pathlib import Path
from urllib.parse import unquote, urlsplit

START = "# >>> antigravity-proxy-macos >>>"
END = "# <<< antigravity-proxy-macos <<<"


def shell_config(current, install, proxy, agy):
    pattern = re.compile(rf"^{re.escape(START)}\n.*?^{re.escape(END)}\n?", re.M | re.S)
    clean = pattern.sub("", current)
    if not install:
        return clean
    return clean + ("" if not clean or clean.endswith("\n") else "\n") + f"""{START}
agy() {{
  local proxy_url={shlex.quote(proxy)}
  local bypass='127.0.0.1,localhost,::1'
  HTTP_PROXY="$proxy_url" HTTPS_PROXY="$proxy_url" NO_PROXY="$bypass" \\
    http_proxy="$proxy_url" https_proxy="$proxy_url" no_proxy="$bypass" \\
    {shlex.quote(agy)} "$@"
}}
{END}
"""


def tile_path(tile):
    url = tile.get("tile-data", {}).get("file-data", {}).get("_CFURLString", "")
    return unquote(urlsplit(url).path).rstrip("/")


def dock_apps(apps, install, launcher, original):
    managed = {str(launcher), str(original), str(launcher.with_name("Antigravity Proxy.app"))}
    managed.add("/Applications/.antigravity-original/Antigravity.app")
    target = launcher if install else original
    result = []
    added = False
    for tile in apps:
        if tile_path(tile) not in managed:
            result.append(tile)
            continue
        if not added and target.exists():
            result.append(dock_tile(target))
            added = True
    if install and not added:
        result.append(dock_tile(target))
    return result


def dock_tile(path):
    return {
        "tile-type": "file-tile",
        "tile-data": {
            "file-label": "Antigravity",
            "file-data": {"_CFURLString": path.as_uri() + "/", "_CFURLStringType": 15},
        },
    }


def main():
    action, proxy, agy, rc, launcher, original, component = sys.argv[1:]
    install = action == "install"
    if component != "app":
        rc = Path(rc)
        current = rc.read_bytes().decode() if rc.exists() else ""
        updated = shell_config(current, install, proxy, agy)
        if updated != current:
            subprocess.run(["/bin/zsh", "-n"], input=updated.encode(), check=True)
            rc.write_bytes(updated.encode())

    if component == "cli":
        return

    domain = "com.apple.dock"
    snapshot = subprocess.run(
        ["/usr/bin/defaults", "export", domain, "-"], capture_output=True, check=True
    ).stdout
    prefs = plistlib.loads(snapshot)
    previous = prefs.get("persistent-apps", [])
    updated_apps = dock_apps(previous, install, Path(launcher), Path(original))
    if updated_apps != previous:
        prefs["persistent-apps"] = updated_apps
        subprocess.run(
            ["/usr/bin/defaults", "import", domain, "-"],
            input=plistlib.dumps(prefs, fmt=plistlib.FMT_BINARY),
            check=True,
        )
        subprocess.run(["/usr/bin/killall", "Dock"], check=False)


if __name__ == "__main__":
    main()
