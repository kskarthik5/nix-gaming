{
  inputs,
  self,
  pins,
  lib,
  build,
  pkgs,
  pkgsCross,
  pkgsi686Linux,
  callPackage,
  fetchFromGitHub,
  fetchurl,
  moltenvk,
  supportFlags,
  stdenv_32bit,
}: let
  nixpkgs-wine = builtins.path {
    path = inputs.nixpkgs;
    name = "source";
    filter = path: type: let
      wineDir = "${inputs.nixpkgs}/pkgs/applications/emulators/wine/";
    in (
      (type == "directory" && (lib.hasPrefix path wineDir))
      || (type != "directory" && (lib.hasPrefix wineDir path))
    );
  };

  defaults = let
    sources = (import "${inputs.nixpkgs}/pkgs/applications/emulators/wine/sources.nix" {inherit pkgs;});
  in {
    inherit sources supportFlags moltenvk;
    patches = [];
    buildScript = "${nixpkgs-wine}/pkgs/applications/emulators/wine/builder-wow.sh";
    configureFlags = ["--disable-tests"];
    geckos = with sources; [gecko32 gecko64];
    mingwGccs = with pkgsCross; [mingw32.buildPackages.gcc mingwW64.buildPackages.gcc];
    monos = with sources.wayland; [mono];
    pkgArches = [pkgs pkgsi686Linux];
    platforms = ["x86_64-linux"];
    stdenv=stdenv_32bit;
  };

  pnameGen = n: n + lib.optionalString (build == "full") "-full";
in {
  wine-ge =
    (callPackage "${nixpkgs-wine}/pkgs/applications/emulators/wine/base.nix" (defaults
      // {
        pname = pnameGen "wine-ge";
        version = pins.proton-wine.branch;
        src = pins.proton-wine;
      }))
    .overrideAttrs (old: {
      meta = old.meta // {passthru.updateScript = ./update-wine-ge.sh;};
    });

  wine-tkg = callPackage "${nixpkgs-wine}/pkgs/applications/emulators/wine/base.nix" (lib.recursiveUpdate defaults
    rec {
      pname = pnameGen "wine-tkg";
      version = lib.removeSuffix "\n" (lib.removePrefix "Wine version " (builtins.readFile "${src}/VERSION"));
      src = pins.wine-tkg;
      supportFlags.waylandSupport = true;
    });

  wine-osu = let
    pname = pnameGen "wine-osu";
    version = "7.22";
    staging = fetchFromGitHub {
      owner = "wine-staging";
      repo = "wine-staging";
      rev = "v${version}";
      sha256 = "sha256-2gBfsutKG0ok2ISnnAUhJit7H2TLPDpuP5gvfMVE44o=";
    };
  in
    (callPackage "${nixpkgs-wine}/pkgs/applications/emulators/wine/base.nix" (defaults
      // rec {
        inherit version pname;
        src = fetchFromGitLab {
          # https://gitlab.collabora.com/alf/wine/-/tree/wayland
          version = "7.22";
          hash = "sha256-Eb2SFBIeQQ3cVZkUQcwNT5mcYe0ShFxBdMc3BlqkwTo=";
          domain = "gitlab.collabora.com";
          owner = "alf";
          repo = "wine";
          rev = "0bd8f9e891bdcd8114103d41eea729702c0a1318";
        };
        patches = ["${nixpkgs-wine}/pkgs/applications/emulators/wine/cert-path.patch"] ++ self.lib.mkPatches ./patches/wine7.22;
        supportFlags = {
          gettextSupport = true;
          fontconfigSupport = true;
          alsaSupport = true;
          openglSupport = true;
          vulkanSupport = true;
          tlsSupport = true;
          cupsSupport = true;
          dbusSupport = true;
          cairoSupport = true;
          cursesSupport = true;
          saneSupport = true;
          pulseaudioSupport = true;
          udevSupport = true;
          xineramaSupport = true;
          sdlSupport = true;
          mingwSupport = true;
          usbSupport = true;
          gtkSupport = true;
          gstreamerSupport = true;
          openclSupport = true;
          odbcSupport = true;
          netapiSupport = true;
          vaSupport = true;
          pcapSupport = true;
          v4lSupport = true;
          gphoto2Support = true;
          krb5Support = true;
          embedInstallers = true;
          waylandSupport = true;
          x11Support = true;
        };
      }))
    .overrideDerivation (old: {
      wineRelease = "wayland";
      nativeBuildInputs = with pkgs; [autoconf perl hexdump] ++ old.nativeBuildInputs;
      prePatch = ''
        patchShebangs tools
        cp -r ${staging}/patches .
        chmod +w patches
        cd patches
        patchShebangs gitapply.sh
        ./patchinstall.sh DESTDIR="$PWD/.." --all ${lib.concatMapStringsSep " " (ps: "-W ${ps}") []}
        cd ..
      '';
    });
}
