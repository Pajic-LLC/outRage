from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


TOOLS = Path(__file__).resolve().parent


class DependencyPrefixTests(unittest.TestCase):
    def test_real_x86_libraries_pass_and_arm_library_fails(self):
        with tempfile.TemporaryDirectory(prefix="outrage prefix ") as directory:
            root = Path(directory)
            (root / "lib").mkdir()
            source = root / "probe.c"
            source.write_text("int probe(void) { return 1; }\n")
            x86 = root / "x86.dylib"
            subprocess.run(["xcrun", "clang", "-arch", "x86_64", "-dynamiclib", str(source), "-o", str(x86)], check=True)
            for name in ["libgmp", "libnettle", "libhogweed", "libfreetype", "libgnutls"]:
                shutil.copyfile(x86, root / "lib" / f"{name}.dylib")
            (root / "outrage-deps.lock").write_text("architecture=x86_64\n")
            command = ["bash", str(TOOLS / "verify-runtime-deps.sh"), str(root)]
            result = subprocess.run(command, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            subprocess.run(["xcrun", "clang", "-arch", "arm64", "-dynamiclib", str(source), "-o", str(root / "lib/libgnutls.dylib")], check=True)
            result = subprocess.run(command, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("dependency is not x86_64", result.stderr)
            (root / "lib/libgnutls.dylib").unlink()
            result = subprocess.run(command, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("missing libgnutls", result.stderr)


if __name__ == "__main__":
    unittest.main()
