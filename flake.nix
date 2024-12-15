{
  description = "A flake for Zig";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";

    # For upgrade use `nix flake update zig`
    zig = {
      url = "github:mitchellh/zig-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };

    # zls = {
    #   url = "github:zigtools/zls";
    #   inputs = {
    #     nixpkgs.follows = "nixpkgs";
    #     flake-utils.follows = "flake-utils";
    #     zig-overlay.follows = "zig";
    #   };
    # };

    zigscient-src = {
      url = "github:llogick/zigscient";
      flake = false;
    };
  };

  outputs =
    inputs@{ self
    , nixpkgs
    , flake-utils
    , ...
    }:
    let
      # zlsBinName = "zls";
      zlsBinName = "zigscient";
      overlays = [
        (final: prev: rec {
          zig = inputs.zig.packages.${prev.system}.master;
          # zls = inputs.zls.packages.${prev.system}.zls;
          zls = prev.stdenvNoCC.mkDerivation {
            name = "zigscient";
            version = "master";
            src = "${inputs.zigscient-src}";
            nativeBuildInputs = [ zig ];
            dontConfigure = true;
            dontInstall = true;
            doCheck = true;
            buildPhase = ''
              mkdir -p .cache
              zig build install --cache-dir $(pwd)/.zig-cache --global-cache-dir $(pwd)/.cache -Dcpu=baseline -Doptimize=ReleaseSafe --prefix $out
            '';
            checkPhase = ''
              zig build test --cache-dir $(pwd)/.zig-cache --global-cache-dir $(pwd)/.cache -Dcpu=baseline
            '';
          };
        })
      ];
    in
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit overlays system; };

        buildInputs = with pkgs; [
          zig
          zls
          xmlstarlet
          coreutils

          # c to ast json
          clang

          # For wireshark build
          bash
          git
          c-ares
          bison
          flex
          ccache
          cmake
          glib
          libgcrypt
          libgpg-error
          libpcap
          pcre2
          perl
          pkg-config
          python3
          speexdsp
        ];
      in
      {
        # run: `nix develop`
        devShells = {
          default = pkgs.mkShell {
            inherit buildInputs;
          };

          # Update IDEA paths. Use only if nix installed in whole system.
          # run: `nix develop \#idea`
          idea = pkgs.mkShell {
            inherit buildInputs;

            shellHook = pkgs.lib.concatLines [
              ''
                # Replace Go Lint path
                if [[ -f .idea/zigbrains.xml ]]; then
                  xmlstarlet ed -L -u '//project/component[@name="ZLSSettings"]/option[@name="zlsPath"]/@value' -v '${pkgs.zls}/bin/${zlsBinName}' .idea/zigbrains.xml
                  xmlstarlet ed -L -u '//project/component[@name="ZigProjectSettings"]/option[@name="toolchainPath"]/@value' -v '${pkgs.zig}/bin' .idea/zigbrains.xml
                  xmlstarlet ed -L -u '//project/component[@name="ZigProjectSettings"]/option[@name="explicitPathToStd"]/@value' -v '${pkgs.zig}/lib' .idea/zigbrains.xml
                fi

                exit 0
              ''
            ];
          };
        };

        # run: `nix fmt .`
        formatter = pkgs.nixfmt-rfc-style;
      }
    );
}
