# Sharkuana - Wireshark plugin bindings for the ZIG language

A **very early**, hand-crafted API for creating Wireshark plugins in the ZIG language.

At the moment, only the ability to build for MacOS Arm has been tested,
but as soon as the main functionality is completed,
support for other OS will be implemented.

## Required Dependencies

At this moment, you need to clone Wireshark to the root of the project and build the libraries:

```shell
git clone https://gitlab.com/wireshark/wireshark.git
cd wireshark
mkdir build && cd build
cmake -DBUILD_wireshark=OFF ..
```

## Building an example plugin

Go to the [example](example) directory and run `zig build`

To quickly test the plugin, use the command:

```shell
zig build && cp zig-out/lib/libsharkuana-example.dylib ~/.local/lib/wireshark/plugins/4-4/epan/libsharkuana-example.so && /Applications/Wireshark.app/Contents/MacOS/Wireshark --log-domains sharkuana,sharkuana_example --log-level noisy
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
