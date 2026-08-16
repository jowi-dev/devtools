# Graphify (https://github.com/Graphify-Labs/graphify) — turns a codebase into
# a queryable knowledge graph for AI coding assistants. Needs the overlay
# below to fix two broken dependencies in nixpkgs.
#
# Returns null when the pkgs set has no `graphify` attribute (e.g. an older
# nixpkgs pin on NixOS), so callers can gracefully skip it instead of failing
# evaluation. Callers must filter out null (see nix/home/common.nix).
{ pkgs }:
let
  overlaidPkgs = pkgs.extend (
    final: prev: {
      pythonPackagesExtensions = (prev.pythonPackagesExtensions or [ ]) ++ [
        (pyfinal: pyprev: {
          # Two generated-code tests fail on a whitespace-only diff in
          # expected output; the package itself works.
          datamodel-code-generator = pyprev.datamodel-code-generator.overridePythonAttrs (_: {
            doCheck = false;
          });
          # The grammar builder names derivations python-tree-sitter-<lang>
          # while the wheel metadata registers tree-sitter-<lang>, so
          # pythonMetadataCheckPhase can never find the distribution.
          tree-sitter-grammars = prev.lib.mapAttrs (
            _: v:
            if prev.lib.isDerivation v && v ? overridePythonAttrs then
              v.overridePythonAttrs (_: { dontCheckPythonMetadata = true; })
            else
              v
          ) pyprev.tree-sitter-grammars;
        })
      ];
    }
  );
in
if overlaidPkgs ? graphify then overlaidPkgs.graphify else null
