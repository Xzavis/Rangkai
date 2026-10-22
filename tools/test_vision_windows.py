import asyncio
import base64
import json
from pathlib import Path
import shlex
import struct
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import vision_windows as vision


PNG = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jR1sAAAAASUVORK5CYII=")


class VisionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.adb = patch.object(vision, "find_adb", return_value="adb.exe")
        self.adb.start()
        self.addCleanup(self.adb.stop)
        self.controller = vision.VisionWindows(output=self.temp.name)

    def fake_adb(self, *args):
        if args == ("-d", "get-serialno"):
            return b"usb-phone\n"
        if args[-1] == "get-state":
            return b"device\n"
        if "screencap" in args:
            return PNG
        return b""

    def test_png_binary_and_native_dimensions_are_preserved(self):
        with patch.object(self.controller, "run_adb", side_effect=self.fake_adb) as run:
            metadata, data = self.controller.execute("screenshot")
        self.assertEqual(data, PNG)
        self.assertEqual((metadata["width"], metadata["height"]), (1, 1))
        self.assertEqual(Path(metadata["image"]).read_bytes(), PNG)
        self.assertEqual(json.loads(Path(metadata["image"]).with_suffix(".json").read_text()), metadata)
        self.assertFalse(metadata["action_sent"])
        self.assertIn(("-d", "get-serialno"), [c.args for c in run.call_args_list])
        self.assertEqual(run.call_args.args[:2], ("-s", "usb-phone"))
        for invalid in (b"error: device offline", PNG[:20], PNG[:-1], PNG[:16] + struct.pack(">II", 0, 1) + PNG[24:]):
            with self.assertRaises(vision.VisionError):
                vision.png_size(invalid)

    def test_multiple_usb_or_unauthorized_does_not_choose_random_device(self):
        with patch.object(self.controller, "run_adb", side_effect=vision.VisionError("more than one device")) as run:
            with self.assertRaisesRegex(vision.VisionError, "more than one"):
                self.controller.execute("screenshot")
            run.assert_called_once_with("-d", "get-serialno")

    def test_explicit_serial_is_used_for_every_device_command(self):
        self.controller.serial = "chosen-phone"
        with patch.object(self.controller, "run_adb", side_effect=self.fake_adb) as run:
            self.controller.execute("screenshot")
        self.assertTrue(all(c.args[:2] == ("-s", "chosen-phone") for c in run.call_args_list))

    def test_invalid_input_never_reaches_adb(self):
        cases = [("tap", {"x": -1, "y": 0}), ("tap", {"x": True, "y": 0}),
                 ("swipe", {"x": 0, "y": 0}), ("text", {"text": "nama\nbaru"}),
                 ("text", {"text": "caf\u00e9"}), ("text", {"text": "literal%s"}),
                 ("key", {"key": "HOME; reboot"}), ("launch", {"package": "x.y;reboot"}),
                 ("screenshot", {"wait_ms": -1}), ("screenshot", {"duration_ms": 10001})]
        with patch.object(self.controller, "run_adb") as run:
            for action, args in cases:
                with self.subTest(action=action, args=args), self.assertRaises(vision.VisionError):
                    self.controller.execute(action, **args)
            run.assert_not_called()

    def test_out_of_bounds_does_not_send_input(self):
        with patch.object(self.controller, "run_adb", side_effect=self.fake_adb) as run:
            with self.assertRaisesRegex(vision.VisionError, "di luar"):
                self.controller.execute("tap", x=1, y=0)
        self.assertFalse(any("input" in c.args for c in run.call_args_list))

    def test_remote_shell_text_is_quoted_and_not_saved(self):
        typed = "hello ; $(id) ' & | < > `id` \\\""
        with patch.object(self.controller, "run_adb", side_effect=self.fake_adb) as run:
            metadata, _ = self.controller.execute("text", text=typed, wait_ms=0)
        command = next(c.args for c in run.call_args_list if "input" in c.args)
        self.assertEqual(shlex.split(" ".join(command[3:])), ["input", "text", typed.replace(" ", "%s")])
        self.assertNotIn(typed, Path(metadata["image"]).with_suffix(".json").read_text())
        self.assertTrue(metadata["action_sent"])
        self.assertEqual(metadata["visual_assertion"], "pending_agent_review")

    def test_no_false_success_when_capture_fails_after_input(self):
        def failed_capture(*args):
            if "screencap" in args:
                raise vision.VisionError("disconnected")
            return self.fake_adb(*args)
        with patch.object(self.controller, "run_adb", side_effect=failed_capture):
            with self.assertRaisesRegex(vision.VisionError, "Aksi sudah dikirim"):
                self.controller.execute("key", key="BACK", wait_ms=0)
        self.assertFalse(list(Path(self.temp.name).glob("*.json")))

    def test_adb_error_and_timeout_are_not_success(self):
        with patch.object(vision.subprocess, "run", return_value=subprocess.CompletedProcess([], 1, b"", b"unauthorized")):
            with self.assertRaisesRegex(vision.VisionError, "unauthorized"):
                self.controller.run_adb("devices")
        with patch.object(vision.subprocess, "run", side_effect=subprocess.TimeoutExpired("adb", 25)):
            with self.assertRaisesRegex(vision.VisionError, "mungkin sudah terkirim"):
                self.controller.run_adb("devices")

    def test_tap_swipe_long_press_key_and_launch(self):
        cases = [("tap", {"x": 0, "y": 0}, ("input", "tap", "0", "0")),
                 ("swipe", {"x": 0, "y": 0, "x2": 0, "y2": 0}, ("input", "swipe", "0", "0", "0", "0", "350")),
                 ("long_press", {"x": 0, "y": 0}, ("input", "swipe", "0", "0", "0", "0", "600")),
                 ("key", {"key": "BACK"}, ("input", "keyevent", "KEYCODE_BACK"))]
        for action, args, expected in cases:
            with self.subTest(action=action), patch.object(self.controller, "run_adb", side_effect=self.fake_adb) as run:
                self.controller.execute(action, **args, wait_ms=0)
                self.assertIn(("-s", "usb-phone", "shell", *expected), [c.args for c in run.call_args_list])
        def launch_adb(*args):
            if "resolve-activity" in args:
                return b"priority=0\ncom.example.cpi/.MainActivity\n"
            return self.fake_adb(*args)
        with patch.object(self.controller, "run_adb", side_effect=launch_adb) as run:
            self.controller.execute("launch", package="com.example.cpi", wait_ms=0)
            self.assertIn(("-s", "usb-phone", "shell", "am", "start", "-W", "-n", "com.example.cpi/.MainActivity"), [c.args for c in run.call_args_list])

    def test_mcp_returns_native_image_and_errors(self):
        async def check():
            server = vision.create_mcp(self.controller)
            tools = await server.list_tools()
            self.assertEqual([t.name for t in tools], ["vision_windows"])
            with patch.object(self.controller, "run_adb", side_effect=self.fake_adb):
                result = await server.call_tool("vision_windows", {"action": "screenshot"})
            self.assertFalse(result.isError)
            self.assertEqual(result.content[1].mimeType, "image/png")
            self.assertEqual(base64.b64decode(result.content[1].data), PNG)
            with patch.object(self.controller, "run_adb", side_effect=vision.VisionError("offline")):
                result = await server.call_tool("vision_windows", {"action": "screenshot"})
            self.assertTrue(result.isError)
            self.assertEqual(result.content[0].text, "offline")
        asyncio.run(check())


if __name__ == "__main__":
    unittest.main()
