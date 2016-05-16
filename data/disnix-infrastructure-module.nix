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
      
      properties = lib.mkOption {
        default = {};
        description = "An attribute set container arbitary machine properties";
      };
      
      generateContainersExpr = lib.mkOption {
        description = "The path to the expression generating the container properties";
        type = lib.types.path;
      };
    };
  };
  
  config = lib.mkIf cfg.enable {
    disnixInfrastructure.infrastructure = {
      properties = {
        hostname = config.networking.hostName;
      } // cfg.properties;
      
      system = if config.nixpkgs.system == "" then builtins.currentSystem else config.nixpkgs.system;
      
      containers = lib.recursiveUpdate (import cfg.generateContainersExpr {
        inherit (cfg) enableAuthentication;
        inherit config lib;
      }) (config.dysnomia.extraContainerProperties or {});
    };
  };
}
