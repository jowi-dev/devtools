{
  description = "jowi personal dev environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    tskmstr.url = "github:jowi-dev/tskmstr";
  };

  outputs = { self, nixpkgs, home-manager, tskmstr, ... }:
    let
      systems = {
        darwin = "aarch64-darwin";
        nixos = "x86_64-linux";
      };

      commonModules = [
        ./nix/home/common.nix
      ];

      # Key outputs by the system string (aarch64-darwin, x86_64-linux) so
      # standard resolution (`nix develop` with no attr) works on every machine.
      forEachSystem = f: builtins.listToAttrs (map (system: {
        name = system;
        value = f nixpkgs.legacyPackages.${system};
      }) (builtins.attrValues systems));
    in
    {
      devShells = forEachSystem (pkgs: {
        default = pkgs.mkShell {
          buildInputs = with pkgs.ocamlPackages; [
            pkgs.ocaml
            dune_3
            ocaml-lsp
          ];
        };
      });

      homeConfigurations = {
        "jowi@darwin" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${systems.darwin};
          extraSpecialArgs = { inherit tskmstr; };
          modules = commonModules ++ [
            {
              home.username = "jowi";
              home.homeDirectory = "/Users/jowi";
            }
          ];
        };

        "jowi@nixos" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${systems.nixos};
          extraSpecialArgs = { inherit tskmstr; };
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
