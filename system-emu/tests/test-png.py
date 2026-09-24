import pathlib
import struct
import subprocess
import sys
import tempfile
import zlib

with tempfile.TemporaryDirectory(dir='.') as directory:
    path = pathlib.Path(directory) / 'test.png'
    subprocess.run([sys.argv[1], str(path)], check=True)
    data = path.read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    pos = 8
    compressed = b''
    while pos < len(data):
        length, = struct.unpack_from('>I', data, pos)
        kind = data[pos + 4:pos + 8]
        payload = data[pos + 8:pos + 8 + length]
        crc, = struct.unpack_from('>I', data, pos + 8 + length)
        assert zlib.crc32(kind + payload) == crc
        if kind == b'IHDR':
            assert struct.unpack('>IIBBBBB', payload) == (2, 2, 8, 2, 0, 0, 0)
        if kind == b'IDAT':
            compressed += payload
        pos += 12 + length
    assert kind == b'IEND'
    assert zlib.decompress(compressed) == bytes([0, 255, 0, 0, 0, 255, 0, 0, 0, 0, 255, 255, 255, 255])
print('PNG CRC, zlib stream, dimensions and RGB pixels: PASS')
