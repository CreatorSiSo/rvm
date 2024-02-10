# Rvm

## Binary Format

The first three bytes define the format version to use:

- first byte: major version
- second byte: minor version
- third byte: patch version

### Version 0.1.0

The next 8 bytes store the length of the rest of the binary data as a `u64` with big endianness.
