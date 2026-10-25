"""Exercise the actual CI audit step with a real Mach-O under a spaced path."""

import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[2]


class RuntimeAuditWorkflowTests(unittest.TestCase):
    def test_installed_path_and_audit_failure_propagation(self):
        workflow = (REPO / ".github/workflows/runtime-build.yml").read_text()
        step = re.search(
            r"- name: Audit runtime self-containment\n        run: \|\n(.*?)(?=      - name:)",
            workflow,
            re.DOTALL,
        )
        self.assertIsNotNone(step)
        script = "\n".join(line[10:] for line in step.group(1).splitlines())

        with tempfile.TemporaryDirectory(prefix="outrage audit ") as directory:
            work = Path(directory)
            runtime = work / "Library/Application Support/outRage/Runtimes/outrage-metal-x86_64"
            runtime.mkdir(parents=True)
            source = work / "smoke.c"
            source.write_text("int smoke(void) { return 0; }\n")
            library = runtime / "libsmoke.dylib"
            subprocess.run(
                ["xcrun", "clang", "-dynamiclib", str(source), "-o", str(library),
                 "-Wl,-install_name,@rpath/libsmoke.dylib"],
                check=True,
            )
            # Stand in only for catalog discovery; use the real workflow parser
            # and the real Mach-O auditor so weakening/skipping the gate fails.
            swift = work / "swift"
            swift.write_text('#!/bin/bash\nprintf "outrage-metal-x86_64\\t%s\\n" "$TEST_RUNTIME_ROOT"\n')
            swift.chmod(0o755)
            env = dict(os.environ, PATH=f"{work}:{os.environ['PATH']}", TEST_RUNTIME_ROOT=str(runtime))

            result = subprocess.run(["bash", "-e", "-o", "pipefail", "-c", script],
                                    cwd=REPO, env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("runtime dylib audit passed", result.stdout)

            subprocess.run(["install_name_tool", "-id", "/opt/homebrew/lib/libsmoke.dylib", str(library)], check=True)
            result = subprocess.run(["bash", "-e", "-o", "pipefail", "-c", script],
                                    cwd=REPO, env=env, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("non-system absolute dylib reference", result.stderr)


if __name__ == "__main__":
    unittest.main()
