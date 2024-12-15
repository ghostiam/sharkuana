# Sharkuana - Wireshark plugin bindings for the ZIG language

A **very early**, API for creating Wireshark plugins in the ZIG language.

At the moment, only the ability to build for MacOS and Linux has been tested,
but as soon as the main functionality is completed, support for Windows will be implemented.

## Build Wireshark libraries

To build the Wireshark libraries, you need to have `nix` installed.

```shell
nix develop --command ./scripts/build-wireshark-libs.bash
```

If you don't have `nix`, you can use the fallback script
which will try using the 
- `nix`;
- `docker` with `nix` (This build will only be for Linux);
- run script locally(You will need to install dependencies manually).

```shell
./nix-fallback.bash ./scripts/build-wireshark-libs.bash
```

[//]: # (TODO: Build in CI and import as zig deps)

## Building a minimal plugin

To quickly test the plugin, use the command:

```shell
zig build && mkdir -p ~/.local/lib/wireshark/plugins/4-4/epan && cp zig-out/lib/libsharkuana.dylib ~/.local/lib/wireshark/plugins/4-4/epan/libsharkuana.so && /Applications/Wireshark.app/Contents/MacOS/Wireshark --log-domains sharkuana --log-level noisy
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
