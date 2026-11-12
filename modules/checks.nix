# Evaluate each module with a sample config and build what it generates.
{
  self,
  nixpkgs,
  home-manager,
  pkgs,
}:
let
  nixos = nixpkgs.lib.nixosSystem {
    modules = [
      self.nixosModules.default
      {
        nixpkgs.hostPlatform = pkgs.stdenv.hostPlatform.system;
        boot.isContainer = true;
        system.stateVersion = "26.05";
        programs.helium = {
          enable = true;
          extensions = [ "dbepggeogbaibhgnhhndojpepiihcmeb" ];
          policies.PasswordManagerEnabled = false;
        };
      }
    ];
  };

  home = home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      self.homeModules.default
      {
        home = {
          username = "test";
          homeDirectory = "/home/test";
          stateVersion = "26.05";
        };
        programs.helium = {
          enable = true;
          commandLineArgs = [ "--enable-wayland-ime" ];
          nativeMessagingHosts = [ pkgs.keepassxc ];
          dictionaries = [ pkgs.hunspellDictsChromium.en_US ];
        };
      }
    ];
  };
in
{
  helium-nixos-module = nixos.config.environment.etc."chromium/policies/managed/helium.json".source;
  helium-home-module = home.activationPackage;
}
