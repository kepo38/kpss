import re
import subprocess
import time
from pathlib import Path

DEVICE = "GAD6ZHBU4LJJ9XVW"
OUT = Path(r"C:\Users\halit\Projects\kpss-akademi\tool\ui_dump.xml")
SHOT = Path(r"C:\Users\halit\Projects\kpss-akademi\tool\demo_benzer.png")


def adb(*args: str) -> bytes:
    return subprocess.check_output(["adb", "-s", DEVICE, *args])


def dump_ui() -> str:
    adb("shell", "uiautomator", "dump", "/sdcard/ui.xml")
    data = adb("exec-out", "cat", "/sdcard/ui.xml")
    OUT.write_bytes(data)
    return data.decode("utf-8", errors="replace")


def find_nodes(xml: str, *needles: str):
    nodes = []
    for m in re.finditer(
        r'text="([^"]*)"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"',
        xml,
    ):
        text = m.group(1)
        low = text.casefold()
        if any(n.casefold() in low for n in needles):
            x1, y1, x2, y2 = map(int, m.groups()[1:])
            nodes.append((text, (x1 + x2) // 2, (y1 + y2) // 2))
    # also content-desc
    for m in re.finditer(
        r'content-desc="([^"]*)"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"',
        xml,
    ):
        text = m.group(1)
        low = text.casefold()
        if any(n.casefold() in low for n in needles):
            x1, y1, x2, y2 = map(int, m.groups()[1:])
            nodes.append((text, (x1 + x2) // 2, (y1 + y2) // 2))
    return nodes


def tap(x: int, y: int) -> None:
    adb("shell", "input", "tap", str(x), str(y))
    time.sleep(1.2)


def screenshot(path: Path) -> None:
    raw = adb("exec-out", "screencap", "-p")
    path.write_bytes(raw)
    print(f"saved {path}")


def main() -> None:
    time.sleep(2)
    xml = dump_ui()
    print("looking for Gelişim / Yanlış...")
    # Bottom nav Gelişim
    for label in ("Gelişim", "Gelisim", "Yanlış", "Yanlis", "Defteri"):
        hits = find_nodes(xml, label)
        if hits:
            print("found", hits[0])
            tap(hits[0][1], hits[0][2])
            xml = dump_ui()
            break

    hits = find_nodes(xml, "Yanlış", "Yanlis", "defteri", "Defteri")
    print("after nav hits", hits[:5])
    if hits:
        tap(hits[0][1], hits[0][2])
        time.sleep(2)
        xml = dump_ui()

    # If still home, try vault cell "Yanlış"
    hits = find_nodes(xml, "YANLIŞ", "Yanlış", "demo_sim", "Paragraf", "ana fikir")
    print("wrong screen candidates", hits[:10])
    if hits:
        # Prefer a question-looking item
        target = next((h for h in hits if "ana" in h[0].casefold() or "demo" in h[0].casefold()), hits[0])
        print("tap", target)
        tap(target[1], target[2])
        xml = dump_ui()

    benzer = find_nodes(xml, "Benzer")
    print("Benzer", benzer)
    if benzer:
        screenshot(Path(str(SHOT).replace(".png", "_before_benzer.png")))
        tap(benzer[0][1], benzer[0][2])
        time.sleep(3)
        screenshot(SHOT)
        xml = dump_ui()
        texts = re.findall(r'text="([^"]+)"', xml)
        print("screen texts:", [t for t in texts if t.strip()][:25])
    else:
        screenshot(SHOT)
        texts = re.findall(r'text="([^"]+)"', xml)
        print("no Benzer yet; texts:", [t for t in texts if t.strip()][:40])


if __name__ == "__main__":
    main()
