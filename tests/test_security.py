import json
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class SecurityGateTests(unittest.TestCase):
    def gate(self, report):
        with tempfile.NamedTemporaryFile(mode="w") as fixture:
            fixture.write(report)
            fixture.flush()
            return subprocess.run(
                ["bash", str(ROOT / "scripts/security-gate.sh"), fixture.name],
                capture_output=True, text=True,
            ).returncode

    def test_severity_boundary_including_unfixed(self):
        for severity, succeeds in [("LOW", True), ("MEDIUM", True),
                                   ("HIGH", False), ("CRITICAL", False)]:
            with self.subTest(severity=severity):
                report = {"SchemaVersion": 2, "Results": [{
                    "Packages": [{"Name": "test", "Version": "1"}],
                    "Vulnerabilities": [{"Severity": severity, "FixedVersion": ""}],
                }]}
                self.assertEqual(self.gate(json.dumps(report)) == 0, succeeds)

    def test_empty_missing_and_malformed_reports_fail(self):
        for report in ["not json", "{}", "null",
                       '{"SchemaVersion":2,"Results":[]}',
                       '{"SchemaVersion":2,"Results":[{"Packages":[]}]}']:
            with self.subTest(report=report):
                self.assertNotEqual(self.gate(report), 0)

    def test_nonempty_clean_inventory_passes(self):
        self.assertEqual(self.gate(json.dumps({"SchemaVersion": 2, "Results": [
            {"Packages": [{"Name": "test", "Version": "1"}]}]})), 0)


if __name__ == "__main__":
    unittest.main()
