# Rvm

## Binary Format

The first three bytes define the format version to use:

- first byte: major version
- second byte: minor version
- third byte: patch version

### Version 0.1.0

The next 2 bytes store how many opcodes come after it as a `u16` with big endianness.

#### Examples

```
\x00\x01\x00
\x00\x00
\x00\x00

version: 0.1.0
opcodes:
constants:
```

```
\x00\x01\x00
\x00\x00
\x00\x02\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\x00\x00\x00\x00\x00\x00\x00\x00

version: 0.1.0
opcodes:
constants:
    [ffffffffffffffff] 18446744073709551615
    [0000000000000000] 0
```

```
\x00\x01\x00
\x00\x02\x02\x00\x00\x00\x00\x00\x00\x00
\x00\x02\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\x00\x00\x00\x00\x00\x00\x00\x00

version: 0.1.0
opcodes:
    [02000000] LoadConstant, 0
    [00000000] Halt, 0
constants:
    [ffffffffffffffff] 18446744073709551615
    [0000000000000000] 0
```
