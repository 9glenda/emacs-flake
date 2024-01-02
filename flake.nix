{
  description = "Emacs config of 9glenda";
  
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs.flake = true;
    emacs-overlay = {
      url = "github:nix-community/emacs-overlay";
    };

    twist.url = "github:emacs-twist/twist.nix";
    org-babel.url = "github:emacs-twist/org-babel";

    gnu-elpa = {
      url = "git+https://git.savannah.gnu.org/git/emacs/elpa.git?ref=main";
      flake = false;
    };
    melpa = {
      url = "github:melpa/melpa";
      flake = false;
    };
    nongnu-elpa = {
      url = "git+https://git.savannah.gnu.org/git/emacs/nongnu.git?ref=main";
      flake = false;
    };
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux"];

      flake = {
        overlays.default = inputs.nixpkgs.lib.composeManyExtensions [
          inputs.emacs-overlay.overlays.emacs
          inputs.org-babel.overlays.default
          inputs.twist.overlays.default
          (final: prev: let
            emacs = final.emacs-pgtk;
          in {
            emacsEnv = (final.emacsTwist {
              emacsPackage = emacs;

              initFiles = [(final.tangleOrgBabelFile "init.el" ./init.org {})];

              lockDir = ./lock;
              registries = import ./nix/registries.nix inputs;
            }).overrideScope' (_tfinal: tprev: {
                elispPackages = tprev.elispPackages.overrideScope' (
                  prev.callPackage ./packageOverrides.nix {inherit (tprev) emacs;}
                );
              });


            emacsConfig = prev.callPackage inputs.self {
              trivialBuild = final.callPackage "${inputs.nixpkgs}/pkgs/build-support/emacs/trivial.nix" {
                emacs = (x: x // {inherit (x.emacs) meta nativeComp withNativeCompilation;}) final.emacsEnv;
              };
            };
          })
        ];
      };

      perSystem = {
        config,
        pkgs,
        inputs',
        ...
      }: {
        _module.args.pkgs = inputs'.nixpkgs.legacyPackages.extend inputs.self.overlays.default;

        formatter = pkgs.alejandra;

        packages = rec {
          inherit (pkgs) emacsConfig emacsEnv;
          emacs = pkgs.symlinkJoin {
            name = "emacs";
            paths = [pkgs.emacsEnv];
            buildInputs = [pkgs.makeWrapper];
            postBuild = ''
              wrapProgram $out/bin/emacs \
                --add-flags "--init-directory ${pkgs.emacsConfig}"
            '';
          };

          default = emacs;
        };

        checks.build-config = config.packages.emacsConfig;
        checks.build-env = config.packages.emacsEnv;

        apps = pkgs.emacsEnv.makeApps {
          lockDirName = "lock";
        };
      };
    };
}
