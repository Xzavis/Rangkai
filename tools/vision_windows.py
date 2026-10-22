"""ADB USB vision control: native PNG frames, coordinate input, optional MCP stdio."""

import argparse
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import struct
import subprocess
import sys
import time
from typing import Literal
from uuid import uuid4


Action = Literal["devices", "screenshot", "tap", "long_press", "swipe", "text", "key", "launch"]
ACTIONS = Action.__args__
KEYS = {"BACK", "HOME", "ENTER", "DEL", "FORWARD_DEL", "TAB", "ESCAPE",
        "APP_SWITCH", "DPAD_UP", "DPAD_DOWN", "DPAD_LEFT", "DPAD_RIGHT", "DPAD_CENTER"}
DEFAULT_OUTPUT = Path(__file__).resolve().parents[1] / "outputs" / "vision_windows"


class VisionError(Exception):
    pass


def find_adb(explicit=None):
    if explicit:
        found = shutil.which(explicit)
        if found:
            return found
        raise VisionError("ADB tidak ditemukan: " + explicit)
    candidates = [shutil.which("adb")]
    for root in (os.getenv("ANDROID_HOME"), os.getenv("ANDROID_SDK_ROOT"),
                 str(Path(os.getenv("LOCALAPPDATA", "")) / "Android" / "Sdk")):
        if root:
            candidates.append(str(Path(root) / "platform-tools" / "adb.exe"))
    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            return candidate
    raise VisionError("Pasang Android platform-tools; tambahkan adb ke PATH atau gunakan --adb.")


def png_size(data):
    if (len(data) < 45 or data[:8] != b"\x89PNG\r\n\x1a\n"
            or data[8:16] != b"\x00\x00\x00\rIHDR"
            or data[-12:] != b"\x00\x00\x00\x00IEND\xaeB`\x82"):
        raise VisionError("Screencap tidak menghasilkan PNG yang valid.")
    width, height = struct.unpack(">II", data[16:24])
    if not width or not height:
        raise VisionError("Ukuran screenshot tidak valid.")
    return width, height


class VisionWindows:
    def __init__(self, adb=None, serial=None, output=DEFAULT_OUTPUT):
        self.adb = find_adb(adb)
        self.serial = serial
        self.output = Path(output).resolve()

    def run_adb(self, *args):
        try:
            result = subprocess.run(
                [self.adb, *args], capture_output=True, timeout=25,
                creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
            )
        except subprocess.TimeoutExpired as exc:
            raise VisionError("ADB timeout; aksi mungkin sudah terkirim. Ambil screenshot sebelum mencoba lagi.") from exc
        except OSError as exc:
            raise VisionError(f"Tidak dapat menjalankan ADB: {exc}") from exc
        if result.returncode:
            detail = (result.stderr or result.stdout).decode("utf-8", errors="replace").strip()
            raise VisionError(f"ADB gagal: {detail}. Periksa kabel, USB debugging dan dialog RSA di HP.")
        return result.stdout

    def capture(self, serial):
        data = self.run_adb("-s", serial, "exec-out", "screencap", "-p")
        return data, png_size(data)

    def execute(self, action, *, x=None, y=None, x2=None, y2=None,
                text=None, key=None, package=None, duration_ms=350, wait_ms=500):
        if action not in ACTIONS:
            raise VisionError("Aksi tidak dikenal.")
        for value, name, maximum in ((duration_ms, "duration_ms", 10000), (wait_ms, "wait_ms", 10000)):
            if type(value) is not int or not 0 <= value <= maximum:
                raise VisionError(f"{name} harus integer 0..{maximum}.")
        if action in ("tap", "long_press", "swipe"):
            points = [(x, y)] + ([(x2, y2)] if action == "swipe" else [])
            if any(type(v) is not int or v < 0 for point in points for v in point):
                raise VisionError("Koordinat harus integer >= 0 dalam pixel screenshot asli.")
        if action == "text":
            if not isinstance(text, str) or not text or len(text) > 2000 or any(not 32 <= ord(c) <= 126 for c in text):
                raise VisionError("Input text mendukung 1..2000 karakter ASCII cetak; Unicode/newline belum didukung.")
            if "%s" in text:
                raise VisionError("Literal %s tidak didukung oleh adb input text.")
        if action == "key" and key not in KEYS:
            raise VisionError("Key harus salah satu: " + ", ".join(sorted(KEYS)))
        if action == "launch" and (not isinstance(package, str) or not re.fullmatch(r"[A-Za-z]\w*(?:\.[A-Za-z]\w*)+", package, re.ASCII)):
            raise VisionError("Package Android tidak valid.")
        if action == "devices":
            return {"action": action, "devices": self.run_adb("devices", "-l").decode("utf-8", errors="replace")}, None

        # Resolve -d once so subsequent commands stay pinned to the same USB phone.
        serial = self.serial or self.run_adb("-d", "get-serialno").decode().strip()
        if not serial or serial == "unknown":
            raise VisionError("Tidak ada HP USB siap. Gunakan devices dan setujui dialog USB debugging.")
        state = self.run_adb("-s", serial, "get-state").decode().strip()
        if state != "device":
            raise VisionError(f"Perangkat {serial} belum siap: {state}")

        command = None
        if action in ("tap", "long_press", "swipe"):
            _, (width, height) = self.capture(serial)
            if any(px >= width or py >= height for px, py in points):
                raise VisionError(f"Koordinat di luar screenshot {width}x{height}.")
            if action == "tap":
                command = ["input", "tap", str(x), str(y)]
            else:
                end = (x2, y2) if action == "swipe" else (x, y)
                command = ["input", "swipe", str(x), str(y), str(end[0]), str(end[1]),
                           str(max(1, duration_ms) if action == "swipe" else max(600, duration_ms))]
        elif action == "text":
            # adb joins remote arguments into an Android shell command; quote there too.
            command = ["input", "text", shlex.quote(text.replace(" ", "%s"))]
        elif action == "key":
            command = ["input", "keyevent", "KEYCODE_" + key]
        elif action == "launch":
            resolved = self.run_adb("-s", serial, "shell", "cmd", "package", "resolve-activity", "--brief", package).decode().strip().splitlines()
            component = resolved[-1] if resolved else ""
            if not re.fullmatch(r"[\w.]+/[\w.$]+", component, re.ASCII):
                raise VisionError("Launcher activity tidak ditemukan untuk " + package)
            command = ["am", "start", "-W", "-n", shlex.quote(component)]

        performed = False
        try:
            if command:
                response = self.run_adb("-s", serial, "shell", *command)
                performed = True
                if action == "launch" and re.search(rb"(?:Error:|Exception|Error type)", response):
                    raise VisionError(response.decode("utf-8", errors="replace").strip())
                time.sleep(wait_ms / 1000)
            data, (width, height) = self.capture(serial)
            self.output.mkdir(parents=True, exist_ok=True)
            image_path = self.output / f"{time.time_ns()}-{action}-{uuid4().hex[:8]}.png"
            image_path.write_bytes(data)
            metadata = {
                "action": action, "serial": serial, "image": str(image_path),
                "width": width, "height": height, "coordinate_space": "native screenshot pixels; origin top-left",
                "action_sent": performed, "visual_assertion": "pending_agent_review",
            }
            # Never record typed text (passwords can be entered through this tool).
            image_path.with_suffix(".json").write_text(json.dumps(metadata, indent=2), encoding="utf-8")
            return metadata, data
        except (VisionError, OSError) as exc:
            if performed:
                raise VisionError(f"Aksi sudah dikirim tetapi hasil belum terverifikasi: {exc}. Ambil screenshot; jangan ulang otomatis.") from exc
            raise


def create_mcp(controller):
    try:
        from mcp.server.fastmcp import FastMCP, Image
        from mcp.types import CallToolResult, TextContent, ToolAnnotations
    except ImportError as exc:
        raise VisionError("Mode MCP membutuhkan: python -m pip install -r tools/vision_windows.requirements.txt") from exc

    server = FastMCP("vision_windows", instructions=(
        "Control Android via ADB USB using images only. Start with screenshot, inspect it, "
        "then issue ONE action at native image pixel coordinates. Inspect the returned image "
        "before continuing. No accessibility snapshots, UIAutomator, XML, OCR or widget selectors. "
        "Action delivery is not proof of app success; verify visually. Screenshots are saved locally."
    ))

    @server.tool(name="vision_windows", structured_output=False,
                 annotations=ToolAnnotations(readOnlyHint=False, destructiveHint=True, idempotentHint=False, openWorldHint=True))
    def vision_windows(action: Action, x: int | None = None, y: int | None = None,
                       x2: int | None = None, y2: int | None = None,
                       text: str | None = None, key: str | None = None,
                       package: str | None = None, duration_ms: int = 350,
                       wait_ms: int = 500) -> CallToolResult:
        """ADB USB vision. devices/screenshot/tap/long_press/swipe/text/key/launch.

        Coordinates are native screenshot pixels (never scaled preview coordinates).
        swipe uses x,y to x2,y2. text types printable ASCII into the focused field.
        key: BACK/HOME/ENTER/DEL/FORWARD_DEL/TAB/ESCAPE/APP_SWITCH/DPAD_*.
        launch needs an installed Android package. Every UI action returns a PNG.
        wait_ms is a settling delay, not a readiness assertion (0..10000).
        """
        try:
            metadata, data = controller.execute(action, x=x, y=y, x2=x2, y2=y2, text=text,
                                                key=key, package=package, duration_ms=duration_ms, wait_ms=wait_ms)
            content = [TextContent(type="text", text=json.dumps(metadata, ensure_ascii=False))]
            if data is not None:
                content.append(Image(data=data, format="png").to_image_content())
            return CallToolResult(content=content, structuredContent=metadata)
        except (VisionError, OSError) as exc:
            return CallToolResult(isError=True, content=[TextContent(type="text", text=str(exc))])

    return server


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=(*ACTIONS, "serve"))
    parser.add_argument("--adb", help="Path adb.exe; default PATH/Android SDK")
    parser.add_argument("--serial", help="Explicit device; default one USB phone (adb -d)")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    for name in ("x", "y", "x2", "y2"):
        parser.add_argument("--" + name, type=int)
    for name in ("text", "key", "package"):
        parser.add_argument("--" + name)
    parser.add_argument("--duration-ms", type=int, default=350)
    parser.add_argument("--wait-ms", type=int, default=500)
    args = vars(parser.parse_args())
    action = args.pop("action")
    try:
        controller = VisionWindows(adb=args.pop("adb"), serial=args.pop("serial"), output=args.pop("output"))
        if action == "serve":
            create_mcp(controller).run(transport="stdio")
        else:
            metadata, _ = controller.execute(action, **args)
            print(json.dumps(metadata, ensure_ascii=True, indent=2))
        return 0
    except (VisionError, OSError) as exc:
        print(json.dumps({"error": str(exc)}, ensure_ascii=True), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
