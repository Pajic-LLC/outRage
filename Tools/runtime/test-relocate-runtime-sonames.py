import importlib.util
from pathlib import Path
import tempfile
import unittest


spec = importlib.util.spec_from_file_location("sonames", Path(__file__).with_name("relocate-runtime-sonames.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class RuntimeSonameTests(unittest.TestCase):
    def test_requires_both_dependencies_and_is_idempotent(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "lib").mkdir()
            header = root / "config.h"
            original = '#define SONAME_LIBGNUTLS "libgnutls.30.dylib"\n#define SONAME_LIBFREETYPE "libfreetype.6.dylib"\n'
            header.write_text(original)
            (root / "lib/libgnutls.30.dylib").touch()
            with self.assertRaisesRegex(RuntimeError, "dependency missing"):
                module.relocate(header, root)
            self.assertEqual(header.read_text(), original)
            (root / "lib/libfreetype.6.dylib").touch()
            module.relocate(header, root)
            once = header.read_text()
            self.assertIn('"@rpath/libgnutls.30.dylib"', once)
            self.assertIn('"@rpath/libfreetype.6.dylib"', once)
            module.relocate(header, root)
            self.assertEqual(header.read_text(), once)

    def test_missing_disabled_or_unexpected_sonames_fail_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for text in ["/* #undef SONAME_LIBGNUTLS */\n", '#define SONAME_LIBGNUTLS "/opt/homebrew/lib/libgnutls.30.dylib"\n']:
                header = root / "config.h"
                header.write_text(text)
                with self.assertRaises(RuntimeError):
                    module.relocate(header, root)
                self.assertEqual(header.read_text(), text)


if __name__ == "__main__":
    unittest.main()
