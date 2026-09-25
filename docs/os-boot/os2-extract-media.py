#!/usr/bin/env python3
"""Extract Warp 4's three CD-install boot diskettes from its High Sierra CD.

Usage: python3 docs/os-boot/os2-extract-media.py SOURCE.iso OUTPUT_DIRECTORY
The source is opened read-only. Outputs are ordinary 1.44 MB FAT images.
"""
from pathlib import Path
import struct
import sys

source, destination = map(Path, sys.argv[1:])
names = {"DISK0.DSK", "DISK1_CD.DSK", "DISK2.DSK"}
found = set()

with source.open("rb") as stream:
    def read(offset, size):
        stream.seek(offset)
        data = stream.read(size)
        if len(data) != size:
            raise ValueError("Truncated High Sierra image")
        return data

    def number(record, offset):
        return struct.unpack_from("<I", record, offset)[0]

    def walk(entry, parent=""):
        data = read(number(entry, 2) * 2048, number(entry, 10))
        pos = 0
        while pos < len(data):
            size = data[pos]
            if not size:
                pos = (pos // 2048 + 1) * 2048
                continue
            record = data[pos:pos + size]
            pos += size
            name = record[33:33 + record[32]]
            if name in (b"\0", b"\1"):
                continue
            name = name.decode("ascii").split(";")[0]
            path = parent + "/" + name
            if record[24] & 2:  # High Sierra flags precede ISO 9660's by one byte.
                walk(record, path)
            elif parent == "/DISKIMGS/OS2/35" and name in names:
                size = number(record, 10)
                if size != 1474560:
                    raise ValueError(f"Unexpected diskette size: {path}: {size}")
                destination.mkdir(parents=True, exist_ok=True)
                (destination / name).write_bytes(read(number(record, 2) * 2048, size))
                found.add(name)
                print(f"{path} -> {destination / name} ({size} bytes)")

    descriptor = read(16 * 2048, 2048)
    if descriptor[8:15] != b"\x01CDROM\x01":
        raise ValueError("Expected a High Sierra primary volume descriptor")
    walk(descriptor[180:214])

if found != names:
    raise ValueError(f"Missing diskettes: {sorted(names - found)}")
