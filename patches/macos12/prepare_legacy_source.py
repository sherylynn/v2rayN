#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def patch(path: str, old: str, new: str, label: str) -> None:
    target = ROOT / path
    text = target.read_text(encoding="utf-8-sig")
    if old not in text:
        raise RuntimeError(f"{label}: expected source pattern not found in {path}")
    target.write_text(text.replace(old, new, 1), encoding="utf-8")
    print(f"patched: {path} ({label})")


patch(
    "v2rayN/GlobalHotKeys/src/GlobalHotKeys/GlobalHotKeys.csproj",
    "<TargetFramework>net10.0</TargetFramework>",
    "<TargetFramework>net8.0</TargetFramework>",
    "GlobalHotKeys net8 target",
)

patch(
    "v2rayN/ServiceLib/Services/UpdateService.cs",
    "                Architecture.RiscV64 => coreInfo?.DownloadUrlLinuxRiscV64,\n",
    "",
    "Architecture.RiscV64 is unavailable on net8",
)

old_compare = '''    private static int ComparePreRelease(string? left, string? right)
    {
        if (string.IsNullOrEmpty(left) && string.IsNullOrEmpty(right))
        {
            return 0;
        }
        if (string.IsNullOrEmpty(left))
        {
            return 1;
        }
        if (string.IsNullOrEmpty(right))
        {
            return -1;
        }

        var leftSpan = left.AsSpan();
        var rightSpan = right.AsSpan();
        using var leftEnum = leftSpan.Split('.').GetEnumerator();
        using var rightEnum = rightSpan.Split('.').GetEnumerator();

        while (true)
        {
            var hasLeft = leftEnum.MoveNext();
            var hasRight = rightEnum.MoveNext();

            if (!hasLeft && !hasRight)
            {
                return 0;
            }
            if (!hasLeft)
            {
                return -1;
            }
            if (!hasRight)
            {
                return 1;
            }

            var leftSegment = leftSpan[leftEnum.Current];
            var rightSegment = rightSpan[rightEnum.Current];

            var segCmp = CompareSegment(leftSegment, rightSegment);
            if (segCmp != 0)
            {
                return segCmp;
            }
        }
    }
'''

new_compare = '''    private static int ComparePreRelease(string? left, string? right)
    {
        if (string.IsNullOrEmpty(left) && string.IsNullOrEmpty(right))
        {
            return 0;
        }
        if (string.IsNullOrEmpty(left))
        {
            return 1;
        }
        if (string.IsNullOrEmpty(right))
        {
            return -1;
        }

        var leftSegments = left.Split('.');
        var rightSegments = right.Split('.');
        var segmentCount = Math.Max(leftSegments.Length, rightSegments.Length);

        for (var i = 0; i < segmentCount; i++)
        {
            if (i >= leftSegments.Length)
            {
                return -1;
            }
            if (i >= rightSegments.Length)
            {
                return 1;
            }

            var segCmp = CompareSegment(leftSegments[i].AsSpan(), rightSegments[i].AsSpan());
            if (segCmp != 0)
            {
                return segCmp;
            }
        }

        return 0;
    }
'''

patch(
    "v2rayN/ServiceLib/Models/Dto/SemanticVersion.cs",
    old_compare,
    new_compare,
    "net8 prerelease version splitting",
)

patch(
    "v2rayN/v2rayN.Desktop/Manager/WindowDialog.cs",
    "            var activeTopmost = openWindows.Reverse().FirstOrDefault(w => w.IsActive);",
    "            var activeTopmost = openWindows.LastOrDefault(w => w.IsActive);",
    "avoid Span.Reverse binding on net8",
)
