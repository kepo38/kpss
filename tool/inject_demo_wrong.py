from pathlib import Path
import re
import subprocess
import sys

DEVICE = "GAD6ZHBU4LJJ9XVW"
PKG = "com.hedefkamu.hedef_kamu"
TMP = Path(r"C:\Users\halit\AppData\Local\Temp\FlutterSharedPreferences.xml")
REMOTE_TMP = "/data/local/tmp/FlutterSharedPreferences.xml"


def adb(*args: str) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(
        ["adb", "-s", DEVICE, *args],
        check=True,
        capture_output=True,
    )


def main() -> None:
    adb("shell", "am", "force-stop", PKG)
    pulled = adb(
        "exec-out",
        "run-as",
        PKG,
        "cat",
        "shared_prefs/FlutterSharedPreferences.xml",
    )
    TMP.write_bytes(pulled.stdout)
    text = TMP.read_text(encoding="utf-8")
    replacement = (
        '<string name="flutter.content_wrong_question_ids">'
        "[&quot;demo_sim_1&quot;]</string>"
    )
    text2, count = re.subn(
        r'<string name="flutter\.content_wrong_question_ids">.*?</string>',
        replacement,
        text,
        count=1,
    )
    if count != 1:
        raise SystemExit(f"expected 1 replacement, got {count}")
    # Android prefers \n; keep XML declaration intact
    TMP.write_text(text2.replace("\r\n", "\n"), encoding="utf-8", newline="\n")
    adb("push", str(TMP), REMOTE_TMP)
    adb(
        "shell",
        "run-as",
        PKG,
        "cp",
        REMOTE_TMP,
        "shared_prefs/FlutterSharedPreferences.xml",
    )
    verify = adb(
        "shell",
        "run-as",
        PKG,
        "grep",
        "content_wrong_question_ids",
        "shared_prefs/FlutterSharedPreferences.xml",
    )
    print(verify.stdout.decode("utf-8", errors="replace").strip())
    adb(
        "shell",
        "am",
        "start",
        "-n",
        f"{PKG}/com.hedefkamu.hedef_kamu.MainActivity",
    )
    print("app launched with demo_sim_1 in wrong notebook")


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as exc:
        sys.stderr.write(exc.stderr.decode("utf-8", errors="replace"))
        raise
