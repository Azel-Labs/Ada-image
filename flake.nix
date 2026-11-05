{
  description = "Pinned ada-image OS build and application-release tooling";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/c5ae371f1a6a7fd27823bc500d9390b38c05fa55";
  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      # APT 3.1.5 can exhaust memory by accumulating delayed-download warnings
      # (Debian #1111554). Use the upstream fix only for the image builder.
      buildApt = pkgs.apt.overrideAttrs (_: {
        version = "3.1.8";
        src = pkgs.fetchFromGitLab {
          domain = "salsa.debian.org";
          owner = "apt-team";
          repo = "apt";
          rev = "3.1.8";
          hash = "sha256-11TjB8tlX3KeBb1IbEWEhnSIaLQOygwYRaLPkkWKvX0=";
        };
      });
      diskTools = with pkgs; [ cryptsetup dosfstools e2fsprogs mtools squashfsTools zstd ];
      builder = pkgs.mkosi.override { extraDeps = diskTools ++ [ buildApt pkgs.dpkg pkgs.gnupg ]; };
      search = pkgs.buildEnv {
        name = "ada-image-tools";
        paths = builder.dependencies;
        pathsToLink = [ "/bin" ];
        ignoreCollisions = true;
      };
      mkosi = pkgs.writeShellScriptBin "mkosi" ''
        exec ${builder}/bin/mkosi --extra-search-path=${search}/bin "$@"
      '';
      systemd = pkgs.systemd.override { withUkify = true; withBootloader = true; };
      ukify = pkgs.writeShellScriptBin "ukify" ''
        exec ${systemd}/lib/systemd/ukify "$@"
      '';
    in {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [ mkosi ukify qemu_test buildApt dpkg binutils util-linux gptfdisk
          python3 go git gzip gnutar coreutils gh openssl ] ++ diskTools;
        ADA_IMAGE_OVMF = "${pkgs.OVMF.fd}/FV/OVMF_CODE.fd";
        ADA_IMAGE_OVMF_VARS = "${pkgs.OVMF.fd}/FV/OVMF_VARS.fd";
      };
    };
}
