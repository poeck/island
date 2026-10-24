self:
{ config, lib, pkgs, ... }:
let cfg = config.services.island;
in {
  options.services.island = {
    enable = lib.mkEnableOption "Island";
    package = lib.mkOption { type = lib.types.package; default = self.packages.${pkgs.stdenv.hostPlatform.system}.default; };
    preview = lib.mkOption { type = lib.types.bool; default = true; description = "Run without owning notification/polkit services or executing session actions."; };
    settings = lib.mkOption {
      type = (pkgs.formats.json {}).type;
      default = {};
      description = "Integration settings written to island/config.json; visual design is fixed.";
    };
  };
  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package pkgs.inter ];
    home.sessionVariables = lib.mkIf (!cfg.preview && (cfg.settings.askpass or false)) {
      SUDO_ASKPASS = "${cfg.package}/bin/island-askpass";
    };
    xdg.configFile."island/config.json".text = builtins.toJSON cfg.settings;
    systemd.user.services.island = {
      Unit = {
        Description = "Island desktop island";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${cfg.package}/bin/island run ${if cfg.preview then "--preview" else "--live"}";
        Restart = "on-failure";
        RestartSec = 2;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
