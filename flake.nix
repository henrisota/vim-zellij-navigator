{
  description = "Seamless navigation between zellij panes and vim splits";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    crane.url = "github:ipetkov/crane";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    crane,
    flake-utils,
    rust-overlay,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [(import rust-overlay)];
        };

        rustWithWasiTarget = pkgs.rust-bin.stable.latest.default.override {
          extensions = ["rust-src" "rust-std" "rust-analyzer"];
          targets = ["wasm32-wasip1"];
        };

        craneLib = (crane.mkLib pkgs).overrideToolchain rustWithWasiTarget;

        vim-zellij-navigator = craneLib.buildPackage {
          src = craneLib.cleanCargoSource (craneLib.path ./.);

          cargoExtraArgs = "--target wasm32-wasip1";

          doCheck = false;
          doNotSign = true;

          buildInputs =
            [
              pkgs.libiconv
            ]
            ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [];
        };
      in {
        apps.default = flake-utils.lib.mkApp {
          drv = pkgs.writeShellScriptBin "vim-zellij-navigator-application" ''
            ${pkgs.lib.getExe pkgs.wasmtime} run ${vim-zellij-navigator}/bin/custom-toolchain.wasm
          '';
        };

        checks = {
          inherit vim-zellij-navigator;
        };

        packages.default = vim-zellij-navigator;

        devShells.default = craneLib.devShell {
          checks = self.checks.${system};

          packages = with pkgs; [
            rustWithWasiTarget
            cargo-audit
            cargo-component
            cargo-edit
            cargo-nextest
            cargo-wasi
            cargo-watch
            clippy
            libiconv
            wasmtime
          ];
        };
      }
    );
}
