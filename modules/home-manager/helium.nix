{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.helium;
  configDir = "${config.xdg.configHome}/net.imput.helium";
in
{
  options.programs.helium = {
    enable = lib.mkEnableOption "the Helium browser";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.callPackage ../../pkgs/helium/package.nix { };
      defaultText = lib.literalMD "the `helium` package from this flake";
      description = "The Helium package to install, or `null` to manage only its configuration.";
    };

    finalPackage = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      readOnly = true;
      description = "The installed package, with {option}`commandLineArgs` applied.";
    };

    commandLineArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "--enable-wayland-ime"
        "--wayland-text-input-version=3"
        "--enable-features=TouchpadOverscrollHistoryNavigation"
      ];
      description = ''
        Flags added to every Helium launch. Helium already uses native Wayland
        when {env}`XDG_SESSION_TYPE` is `wayland`, as on Hyprland.
      '';
    };

    nativeMessagingHosts = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = lib.literalExpression "[ pkgs.keepassxc ]";
      description = "Packages providing native messaging hosts in {file}`etc/chromium/native-messaging-hosts`.";
    };

    dictionaries = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = lib.literalExpression "[ pkgs.hunspellDictsChromium.en_US ]";
      description = "Spellcheck dictionaries, from {var}`pkgs.hunspellDictsChromium`.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.package != null || cfg.commandLineArgs == [ ];
        message = "programs.helium.commandLineArgs needs programs.helium.package to be set.";
      }
    ];

    programs.helium.finalPackage =
      if cfg.package == null || cfg.commandLineArgs == [ ] then
        cfg.package
      else
        cfg.package.override { commandLineArgs = lib.concatStringsSep " " cfg.commandLineArgs; };

    home.packages = lib.mkIf (cfg.finalPackage != null) [ cfg.finalPackage ];

    home.file =
      lib.listToAttrs (
        map (pkg: {
          name = "${configDir}/Dictionaries/${pkg.passthru.dictFileName}";
          value.source = pkg;
        }) cfg.dictionaries
      )
      // {
        "${configDir}/NativeMessagingHosts" = lib.mkIf (cfg.nativeMessagingHosts != [ ]) {
          source = "${
            pkgs.symlinkJoin {
              name = "helium-native-messaging-hosts";
              paths = cfg.nativeMessagingHosts;
            }
          }/etc/chromium/native-messaging-hosts";
          recursive = true;
        };
      };
  };
}
