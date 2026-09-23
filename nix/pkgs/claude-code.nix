# Claude Code pinned directly to Anthropic's official native-binary releases,
# bypassing nixpkgs packaging lag. Bump with scripts/update-ai-sources.sh,
# which reads upstream's published checksums (no download needed).
#
# The linux artifact is the glibc build, patched by autoPatchelfHook so it finds
# the loader and libstdc++/libgcc_s in the store. (The musl builds are not
# static: they need /lib/ld-musl-x86_64.so.1, which NixOS lacks.) The hook is
# gated to Linux because it must never run on darwin — see the thatch flake's
# Linux-gating lesson.
{ pkgs }:
let
  sources = builtins.fromJSON (builtins.readFile ./ai-sources.json);
  cc = sources."claude-code";
  system = pkgs.stdenv.hostPlatform.system;
  platform = cc.platforms.${system}
    or (throw "claude-code: no pinned artifact for ${system} in ai-sources.json");
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "claude-code";
  version = cc.version;

  src = pkgs.fetchurl {
    url = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/${cc.version}/${platform.artifact}/claude";
    sha256 = platform.sha256;
  };

  dontUnpack = true;

  nativeBuildInputs = [ pkgs.makeBinaryWrapper ]
    ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.autoPatchelfHook ];
  # The binary is a Bun executable with the app bundle embedded in it;
  # stripping would destroy that bundle.
  dontStrip = true;

  buildInputs = pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.stdenv.cc.cc.lib ];

  # The native binary self-updates into ~/.local/share/claude, which would
  # silently diverge from the store copy on PATH — keep updates in nix's hands.
  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/libexec/claude
    makeBinaryWrapper $out/libexec/claude $out/bin/claude \
      --set DISABLE_AUTOUPDATER 1
    runHook postInstall
  '';

  meta = {
    description = "Anthropic's Claude Code CLI (official prebuilt binary)";
    homepage = "https://claude.com/claude-code";
    mainProgram = "claude";
    platforms = builtins.attrNames cc.platforms;
  };
}
