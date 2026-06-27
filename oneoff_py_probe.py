#!/usr/bin/env python3
import ssl
import sys
import urllib.error
import urllib.request


def main() -> int:
    marker = sys.argv[1] if len(sys.argv) > 1 else "NO_MARKER"
    url = f"https://records.thecuely.com/sandbox-escape/oneoff-py/{marker}"
    ctx = ssl._create_unverified_context()
    try:
        with urllib.request.urlopen(url, context=ctx, timeout=5) as response:
            print(f"oneoff_py REACHED status={response.status} marker={marker}")
            return 0
    except urllib.error.URLError as exc:
        print(f"oneoff_py BLOCKED marker={marker} err={exc}")
        return 1
    except OSError as exc:
        print(f"oneoff_py BLOCKED marker={marker} err={exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
