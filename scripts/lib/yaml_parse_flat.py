#!/usr/bin/env python3
"""Flat YAML frontmatter parser (stdlib only, no PyYAML).

Reads frontmatter body from stdin, emits KEY=VALUE lines to stdout.
Supports flat key: value and key: [a, b, c] lists only (no nesting).
"""
import sys
import re


def strip_inline_comment(s):
    out = []
    in_s = in_d = False
    i = 0
    while i < len(s):
        c = s[i]
        if c == '\\' and i + 1 < len(s):
            out.append(c)
            out.append(s[i + 1])
            i += 2
            continue
        if c == "'" and not in_d:
            in_s = not in_s
        elif c == '"' and not in_s:
            in_d = not in_d
        if c == '#' and not in_s and not in_d:
            if i == 0 or s[i - 1] in ' \t':
                break
        out.append(c)
        i += 1
    return ''.join(out).strip()


def unquote(v):
    v = v.strip()
    if len(v) >= 2 and ((v[0] == '"' and v[-1] == '"') or (v[0] == "'" and v[-1] == "'")):
        return v[1:-1]
    return v


def emit(k, v):
    v = v.strip()
    if v.startswith('[') and v.endswith(']'):
        inner = v[1:-1]
        parts = [unquote(p) for p in re.split(r',', inner) if p.strip() != '']
        print(k + '=' + ','.join(parts))
    else:
        print(k + '=' + unquote(v))


def main():
    try:
        for raw in sys.stdin.read().splitlines():
            line = strip_inline_comment(raw)
            if line == '' or ':' not in line:
                continue
            k, _, v = line.partition(':')
            k = k.strip()
            if k == '':
                continue
            emit(k, v)
    except Exception:
        sys.exit(1)


if __name__ == '__main__':
    main()
