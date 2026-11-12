{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.helium;
  jsonFormat = pkgs.formats.json { };
in
{
  options.programs.helium = {
    enable = lib.mkEnableOption "system-wide policies for the Helium browser";

    extensions = lib.mkOption {
      type = lib.types.listOf (lib.types.strMatching "[a-p]{32}(;.+)?");
      default = [ ];
      example = [
        "nngceckbapebfimnlniiiahkandclblb" # Bitwarden
        "dbepggeogbaibhgnhhndojpepiihcmeb" # Vimium
      ];
      description = ''
        Extensions to force-install, as Chrome Web Store IDs, or as
        `"<id>;<update URL>"` for extensions hosted elsewhere.
        Users can't disable or remove them. Helium downloads Web Store
        extensions through its own services, so they only install once
        Helium services are enabled during onboarding (`helium://setup`).
      '';
    };

    policies = lib.mkOption {
      inherit (jsonFormat) type;
      default = { };
      example = {
        PasswordManagerEnabled = false;
        BrowserSignin = 0;
      };
      description = ''
        Chromium enterprise policies, written to
        {file}`/etc/chromium/policies/managed/helium.json`.
        Chromium reads that directory too, so these also apply to it, and a
        policy set here overrides the same policy from NixOS's
        {option}`programs.chromium` (lists such as
        `ExtensionInstallForcelist` are replaced, not combined).
        See <https://chromeenterprise.google/policies/>.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.helium.policies.ExtensionInstallForcelist = lib.mkIf (
      cfg.extensions != [ ]
    ) cfg.extensions;

    environment.etc."chromium/policies/managed/helium.json" = lib.mkIf (cfg.policies != { }) {
      source = jsonFormat.generate "helium-policies.json" cfg.policies;
    };
  };
}
