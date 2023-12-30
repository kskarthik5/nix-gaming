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
  stdenv
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
    sources = (import "${inputs.nixpkgs}/pkgs/applications/emulators/wine/sources.nix" {inherit pkgs;}).unstable;
  in {
    inherit supportFlags moltenvk;
    patches = [];
    buildScript = "${nixpkgs-wine}/pkgs/applications/emulators/wine/builder-wow.sh";
    configureFlags = ["--disable-tests"];
    geckos = with sources; [gecko32 gecko64];
    mingwGccs = with pkgsCross; [mingw32.buildPackages.gcc mingwW64.buildPackages.gcc];
    monos = with sources; [mono];
    pkgArches = [pkgs pkgsi686Linux];
    platforms = ["x86_64-linux"];
    stdenv = stdenv_32bit;
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
    version = "7.11";
    staging = fetchurl {
      url = "https://github.com/wine-staging/wine-staging/archive/v7.11/wine-staging-v7.11.tar.gz";
      sha256 = "f706e242dcd5d687e636f670415c313059fd76680c7909b7aa3d1848f14700ca";
    };
  in
    (callPackage "${nixpkgs-wine}/pkgs/applications/emulators/wine/base.nix" (defaults
      // rec {
        inherit version pname;
        src = fetchurl {
          url="https://dl.winehq.org/wine/source/7.x/wine-7.11.tar.xz";
          sha256 = "fa28deed99efba8e4b0cd9bb56ce62e57a4d15560baebd4bd69b6754ab41dc3f";
        };
        patches = ["${nixpkgs-wine}/pkgs/applications/emulators/wine/cert-path.patch"] ++ self.lib.mkPatches ./patches;
        supportFlags = {
          waylandSupport = true;
          mingwSupport = true;
          gettextSupport = true;
          fontconfigSupport = stdenv.isLinux;
          alsaSupport = stdenv.isLinux;
          openglSupport = true;
          vulkanSupport = true;
          tlsSupport = true;
          cupsSupport = true;
          dbusSupport = stdenv.isLinux;
          cairoSupport = stdenv.isLinux;
          cursesSupport = true;
          saneSupport = stdenv.isLinux;
          pulseaudioSupport = config.pulseaudio or stdenv.isLinux;
          udevSupport = stdenv.isLinux;
          xineramaSupport = stdenv.isLinux;
          sdlSupport = true;
          mingwSupport = true;
          usbSupport = true;
          gtkSupport = stdenv.isLinux;
          gstreamerSupport = true;
          openclSupport = true;
          odbcSupport = true;
          netapiSupport = stdenv.isLinux;
          vaSupport = stdenv.isLinux;
          pcapSupport = true;
          v4lSupport = stdenv.isLinux;
          gphoto2Support = true;
          krb5Support = true;
          embedInstallers = true;
        };
      }))
    .overrideDerivation (old: {
      nativeBuildInputs = with pkgs; [autoconf perl hexdump] ++ old.nativeBuildInputs;
      prePatch = ''
        patchShebangs tools
        tar -xvf ${staging}
        cp -r wine-staging-7.11/patches ./
        chmod +w patches
        cd patches
        patchShebangs gitapply.sh
        ./patchinstall.sh DESTDIR="$PWD/.." --all ${lib.concatMapStringsSep " " (ps: "-W ${ps}") []}
        cd ..
      '';
    });
}