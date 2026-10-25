"""Prove transitive dylib relocation and dlopen after removing the build prefix."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


TOOLS = Path(__file__).resolve().parent


class RuntimeBundlingTests(unittest.TestCase):
    def test_relocated_runtime_loads_private_libraries_without_build_prefix(self):
        with tempfile.TemporaryDirectory(prefix="outrage bundling ") as directory:
            work = Path(directory)
            prefix = work / "dependency prefix"
            runtime = work / "staged runtime"
            (prefix / "lib").mkdir(parents=True)
            (runtime / "bin").mkdir(parents=True)
            modules = runtime / "lib/wine/x86_64-unix"
            modules.mkdir(parents=True)

            def compile_file(name, source, output, *flags):
                path = work / name
                path.write_text(source)
                subprocess.run(["xcrun", "clang", "-O2", str(path), "-o", str(output), *flags], check=True)

            base = prefix / "lib/libbase.1.dylib"
            compile_file("base.c", "int base(void) { return 42; }", base,
                         "-dynamiclib", f"-Wl,-install_name,{base}")
            (prefix / "lib/libbase.dylib").symlink_to(base.name)
            consumer = prefix / "lib/libconsumer.1.dylib"
            compile_file("consumer.c", "extern int base(void); int value(void) { return base(); }",
                         consumer, "-dynamiclib", f"-Wl,-install_name,{consumer}", str(base))
            (prefix / "lib/libconsumer.dylib").symlink_to(consumer.name)

            compile_file("module.c", '''
#include <dlfcn.h>
#include <stdio.h>
int probe(void) {
    void *library = dlopen("@rpath/libconsumer.1.dylib", RTLD_NOW);
    if (!library) { fprintf(stderr, "%s\\n", dlerror()); return 1; }
    int (*value)(void) = dlsym(library, "value");
    int status = value && value() == 42 ? 0 : 2;
    dlclose(library);
    return status;
}
''', modules / "schannel.so", "-dynamiclib", "-Wl,-headerpad_max_install_names",
                         "-Wl,-install_name,@rpath/schannel.so")
            compile_file("loader.c", '''
#include <dlfcn.h>
#include <stdio.h>
int main(int argc, char **argv) {
    if (argc != 2) return 3;
    void *module = dlopen(argv[1], RTLD_NOW);
    if (!module) { fprintf(stderr, "%s\\n", dlerror()); return 4; }
    int (*probe)(void) = dlsym(module, "probe");
    return probe ? probe() : 5;
}
''', runtime / "bin/loader", "-Wl,-headerpad_max_install_names")

            subprocess.run(["bash", str(TOOLS / "bundle-runtime-dylibs.sh"), str(prefix), str(runtime)], check=True)
            relocated = work / "Application Support/outRage/Runtimes/test"
            relocated.parent.mkdir(parents=True)
            shutil.move(runtime, relocated)
            shutil.rmtree(prefix)
            env = {key: value for key, value in os.environ.items() if not key.startswith("DYLD_")}
            subprocess.run([str(relocated / "bin/loader"), str(relocated / "lib/wine/x86_64-unix/schannel.so")],
                           env=env, check=True)
            subprocess.run(["bash", str(TOOLS / "audit-runtime-dylibs.sh"), str(relocated)], check=True)
            for candidate in relocated.rglob("*"):
                if candidate.is_file() and not candidate.is_symlink():
                    subprocess.run(["codesign", "--verify", str(candidate)], check=True)


if __name__ == "__main__":
    unittest.main()
