# opencode pinned directly to the official per-platform npm binaries
# (@opencode/cli-<platform>, the v2 packages; v1 shipped as opencode-<platform>),
# bypassing nixpkgs packaging lag. Bump with scripts/update-ai-sources.sh,
# which reads the npm registry's SRI integrity hashes (no download needed).
#
# The linux artifact is the glibc build, patched by autoPatchelfHook so it finds
# the loader and libstdc++/libgcc_s in the store. (The musl builds are not
# static: they need /lib/ld-musl-x86_64.so.1, which NixOS lacks.) The hook is
# gated to Linux because it must never run on darwin — see the thatch flake's
# Linux-gating lesson.
{ pkgs }:
let
  sources = builtins.fromJSON (builtins.readFile ./ai-sources.json);
  oc = sources.opencode;
  system = pkgs.stdenv.hostPlatform.system;
  platform = oc.platforms.${system}
    or (throw "opencode: no pinned artifact for ${system} in ai-sources.json");
  # Scoped tarballs drop the scope from the file name:
  # @opencode/cli-darwin-arm64 -> .../@opencode/cli-darwin-arm64/-/cli-darwin-arm64-<ver>.tgz
  tarballName = pkgs.lib.last (pkgs.lib.splitString "/" platform.npmPackage);
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "opencode";
  version = oc.version;

  src = pkgs.fetchurl {
    url = "https://registry.npmjs.org/${platform.npmPackage}/-/${tarballName}-${oc.version}.tgz";
    hash = platform.hash;
  };

  # npm tarballs unpack to package/
  sourceRoot = "package";

  nativeBuildInputs = pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.autoPatchelfHook ];
  # The binary is a Bun executable with the app bundle embedded in it;
  # stripping would destroy that bundle.
  dontStrip = true;

  buildInputs = pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.stdenv.cc.cc.lib ];

  installPhase = ''
    runHook preInstall
    install -Dm755 bin/opencode $out/bin/opencode
    runHook postInstall
  '';

  meta = {
    description = "opencode AI coding agent (official prebuilt binary)";
    homepage = "https://opencode.ai";
    mainProgram = "opencode";
    platforms = builtins.attrNames oc.platforms;
  };
}
