{ config, pkgs, ... }:

with pkgs.lib;

let
  cfg = config.disnixInfrastructure;
in
{
  options = {
    disnixInfrastructure = {
      enable = mkOption {
        default = false;
        description = "Whether to enable infrastructure publishing";
      };
    
      enableAuthentication = mkOption {
        default = false;
        description = "Whether to publish authentication credentials through the infrastructure attribute (not recommended in combination with Avahi)";
      };
    
      infrastructure = mkOption {
        default = {};
        description = "An attribute set containing infrastructure model properties";
      };
    };
  };
  
  config = mkIf cfg.enable {
    disnixInfrastructure.infrastructure =
      { hostname = config.networking.hostName;
        system = if config.nixpkgs.system == "" then builtins.currentSystem else config.nixpkgs.system;
      }
      // optionalAttrs (config.services.disnix.useWebServiceInterface) { targetEPR = "http://${config.networking.hostName}:8080/DisnixWebService/services/DisnixWebService"; }
      // optionalAttrs (config.services.httpd.enable) { documentRoot = config.services.httpd.documentRoot; }
      // optionalAttrs (config.services.mysql.enable) { mysqlPort = config.services.mysql.port; }
      // optionalAttrs (config.services.tomcat.enable) { tomcatPort = 8080; }
      // optionalAttrs (config.services.svnserve.enable) { svnBaseDir = config.services.svnserve.svnBaseDir; }
      // optionalAttrs (cfg.enableAuthentication) (
          optionalAttrs (config.services.mysql.enable) { mysqlUsername = "root"; mysqlPassword = builtins.readFile config.services.mysql.rootPassword; }
        );

  };
}
