from pathlib import Path
import re
import shutil

ROOT = Path(__file__).resolve().parents[2]
GRADLE = ROOT / "android/app/build.gradle.kts"
MANIFEST = ROOT / "android/app/src/main/AndroidManifest.xml"
KROOT = ROOT / "android/app/src/main/kotlin"
GITIGNORE = ROOT / "android/.gitignore"
PACKAGE = "com.burakozturk.linkball"

def backup(path):
    bak = path.with_suffix(path.suffix + ".step06a.bak")
    if path.exists() and not bak.exists():
        shutil.copy2(path, bak)

def write_lf(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        handle.write(text.replace("\r\n", "\n").replace("\r", "\n"))

def main():
    for path in (GRADLE, MANIFEST, GITIGNORE):
        if not path.exists():
            raise RuntimeError(f"Missing: {path.relative_to(ROOT)}")

    gradle = GRADLE.read_text(encoding="utf-8", errors="replace")

    if "import java.io.FileInputStream" not in gradle:
        gradle = (
            "import java.io.FileInputStream\n"
            "import java.util.Properties\n\n"
            + gradle
        )

    if "val keystoreProperties = Properties()" not in gradle:
        loader = (
            'val keystoreProperties = Properties()\n'
            'val keystorePropertiesFile = rootProject.file("key.properties")\n'
            'if (keystorePropertiesFile.exists()) {\n'
            '    keystoreProperties.load(FileInputStream(keystorePropertiesFile))\n'
            '}\n\n'
        )
        gradle = gradle.replace("android {", loader + "android {", 1)

    gradle = re.sub(
        r'namespace\s*=\s*"[^"]+"',
        f'namespace = "{PACKAGE}"',
        gradle,
        count=1,
    )
    gradle = re.sub(
        r'applicationId\s*=\s*"[^"]+"',
        f'applicationId = "{PACKAGE}"',
        gradle,
        count=1,
    )
    gradle = re.sub(
        r'compileSdk\s*=\s*(?:flutter\.compileSdkVersion|\d+)',
        'compileSdk = 36',
        gradle,
        count=1,
    )
    gradle = re.sub(
        r'targetSdk\s*=\s*(?:flutter\.targetSdkVersion|\d+)',
        'targetSdk = 36',
        gradle,
        count=1,
    )

    if 'create("release")' not in gradle:
        signing = (
            '    signingConfigs {\n'
            '        create("release") {\n'
            '            if (keystorePropertiesFile.exists()) {\n'
            '                keyAlias = keystoreProperties["keyAlias"] as String\n'
            '                keyPassword = keystoreProperties["keyPassword"] as String\n'
            '                storeFile = file(keystoreProperties["storeFile"] as String)\n'
            '                storePassword = keystoreProperties["storePassword"] as String\n'
            '            }\n'
            '        }\n'
            '    }\n\n'
        )
        if "    buildTypes {" not in gradle:
            raise RuntimeError("buildTypes block not found")
        gradle = gradle.replace("    buildTypes {", signing + "    buildTypes {", 1)

    gradle = gradle.replace(
        'signingConfig = signingConfigs.getByName("debug")',
        'signingConfig = signingConfigs.getByName("release")',
    )

    backup(GRADLE)
    write_lf(GRADLE, gradle)

    manifest = MANIFEST.read_text(encoding="utf-8", errors="replace")
    manifest = re.sub(
        r'android:label="[^"]*"',
        'android:label="Linkball"',
        manifest,
        count=1,
    )
    backup(MANIFEST)
    write_lf(MANIFEST, manifest)

    mains = list(KROOT.rglob("MainActivity.kt"))
    if len(mains) != 1:
        raise RuntimeError(f"MainActivity count={len(mains)}")
    source = mains[0]
    code = source.read_text(encoding="utf-8", errors="replace")
    code = re.sub(
        r'^package\s+[A-Za-z0-9_.]+',
        f'package {PACKAGE}',
        code,
        count=1,
        flags=re.M,
    )
    target = KROOT / Path(*PACKAGE.split(".")) / "MainActivity.kt"
    backup(source)
    write_lf(target, code)
    if source.resolve() != target.resolve():
        source.unlink()

    gi = GITIGNORE.read_text(encoding="utf-8", errors="replace").splitlines()
    for item in ["key.properties", "**/*.keystore", "**/*.jks"]:
        if item not in gi:
            gi.append(item)
    backup(GITIGNORE)
    write_lf(GITIGNORE, "\n".join(gi).rstrip() + "\n")

    print("[OK] applicationId/namespace =", PACKAGE)
    print("[OK] compileSdk/targetSdk = 36")
    print("[OK] release signing slot prepared")
    print("[OK] Android label = Linkball")

if __name__ == "__main__":
    main()
