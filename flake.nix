{
  description = "jowi personal dev environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }:
    let
      systems = {
        darwin = "aarch64-darwin";
        nixos = "x86_64-linux";
      };

      commonModules = [
        ./nix/home/common.nix
      ];

      forEachSystem = f: builtins.mapAttrs (name: system:
        f nixpkgs.legacyPackages.${system}
      ) systems;
    in
    {
      devShells = forEachSystem (pkgs: {
        default = pkgs.mkShell {
          buildInputs = with pkgs.ocamlPackages; [
            pkgs.ocaml
            dune_3
          ];
        };
      });

      homeConfigurations = {
        "jowi@darwin" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${systems.darwin};
          modules = commonModules ++ [
            {
              home.username = "jowi";
              home.homeDirectory = "/Users/jowi";
            }
          ];
        };

        "jowi@nixos" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${systems.nixos};
          modules = commonModules ++ [
            {
              home.username = "jowi";
              home.homeDirectory = "/home/jowi";
            }
          ];
        };
      };

      packages = {
        ${systems.darwin}.j = import ./nix/pkgs/j.nix {
          pkgs = nixpkgs.legacyPackages.${systems.darwin};
        };
        ${systems.nixos}.j = import ./nix/pkgs/j.nix {
          pkgs = nixpkgs.legacyPackages.${systems.nixos};
        };
      };

      templates = import ./templates/default.nix;
    };
}
