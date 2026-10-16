"""GPU-free checks of the public launcher and Compose wrapper contracts."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class RuntimePolicyTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.path = Path(self.tmp.name)
        self.bin = self.path / "bin"
        self.bin.mkdir()
        self.calls = self.path / "calls"
        self.env = {
            "PATH": f"{self.bin}:{os.environ['PATH']}",
            "HOME": str(self.path),
            "HF_HOME": str(self.path / "cache"),
            "HF_CACHE_PATH": str(self.path / "cache"),
            "HF_MODULES_CACHE": str(self.path / "modules"),
            "XDG_CONFIG_HOME": str(self.path / "config"),
            "VLLM_API_KEY": "test-only",
            "CALL_LOG": str(self.calls),
            # The launcher must override an unsafe inherited value.
            "VLLM_MEDIA_URL_ALLOW_REDIRECTS": "1",
        }
        self.stub("id", "#!/bin/sh\necho 1000\n")
        self.stub("docker", '#!/bin/sh\nprintf "%s\\n" "$*" >> "$CALL_LOG"\n')
        self.stub("vllm", """#!/usr/bin/env python3
import json, os, sys
with open(os.environ['CALL_LOG'], 'w') as f:
    json.dump({'args': sys.argv[1:],
               'redirects': os.environ['VLLM_MEDIA_URL_ALLOW_REDIRECTS']}, f)
""")

    def stub(self, name, content):
        target = self.bin / name
        target.write_text(content)
        target.chmod(0o755)

    def run_script(self, name, *args):
        return subprocess.run(
            [str(ROOT / "scripts" / name), *args],
            env=self.env, text=True, capture_output=True, check=False,
        )

    def test_root_is_rejected_before_launch_but_can_stop(self):
        self.stub("id", "#!/bin/sh\necho 0\n")
        for script, args in (("serve.sh", ()), ("compose.sh", ("up", "-d")),
                             ("compose.sh", ("start",))):
            with self.subTest(script=script, args=args):
                result = self.run_script(script, *args)
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertIn("root", result.stderr)
                self.assertFalse(self.calls.exists())
        result = self.run_script("compose.sh", "down", "--remove-orphans")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls.read_text().strip(), "compose down --remove-orphans")

    def test_both_presets_launch_with_restricted_media_and_no_docs(self):
        for preset in ("Qwen3.6-35B-A3B", "Qwen3.6-27B"):
            with self.subTest(preset=preset):
                self.env["MODEL_PRESET"] = preset
                config = (self.path / "cache" / "hub" /
                          f"models--unsloth--{preset}-NVFP4" / "snapshots" /
                          "test" / "config.json")
                config.parent.mkdir(parents=True)
                config.write_text("{}")
                result = self.run_script("serve.sh")
                self.assertEqual(result.returncode, 0, result.stderr)
                call = json.loads(self.calls.read_text())
                args = call["args"]
                self.assertEqual(args[:2], ["serve", f"unsloth/{preset}-NVFP4"])
                self.assertIn("--disable-fastapi-docs", args)
                self.assertEqual(args[args.index("--allowed-media-domains") + 1],
                                 "invalid.invalid")
                self.assertNotIn("--allowed-local-media-path", args)
                self.assertEqual(call["redirects"], "0")
                self.calls.unlink()
                result = self.run_script("compose.sh", "up", "-d")
                self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
