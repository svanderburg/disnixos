{ config, pkgs, lib, ... }:

let
  cfg = config.disnixInfrastructure;
in
{
  options = {
    disnixInfrastructure = {
      enable = lib.mkOption {
        default = false;
        description = "Whether to enable infrastructure publishing";
      };
    
      enableAuthentication = lib.mkOption {
        default = false;
        description = "Whether to publish authentication credentials through the infrastructure attribute (not recommended in combination with Avahi)";
      };
    
      infrastructure = lib.mkOption {
        default = {};
        description = "An attribute set containing infrastructure model properties";
      };
    };
  };
  
  config = lib.mkIf cfg.enable {
    disnixInfrastructure.infrastructure =
      { hostname = config.networking.hostName;
        system = if config.nixpkgs.system == "" then builtins.currentSystem else config.nixpkgs.system;
      }
      // lib.optionalAttrs (config.services.disnix.useWebServiceInterface) { targetEPR = "http://${config.networking.hostName}:8080/DisnixWebService/services/DisnixWebService"; }
      // lib.optionalAttrs (config.services.httpd.enable) { documentRoot = config.services.httpd.documentRoot; }
      // lib.optionalAttrs (config.services.mysql.enable) { mysqlPort = config.services.mysql.port; }
      // lib.optionalAttrs (config.services.tomcat.enable) { tomcatPort = 8080; }
      // lib.optionalAttrs (config.services.svnserve.enable) { svnBaseDir = config.services.svnserve.svnBaseDir; }
      // lib.optionalAttrs (cfg.enableAuthentication) (
          lib.optionalAttrs (config.services.mysql.enable) { mysqlUsername = "root"; mysqlPassword = builtins.readFile config.services.mysql.rootPassword; }
        )
      // config.services.disnix.infrastructure;

  };
}
