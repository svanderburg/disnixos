{nixpkgs, nixos, pkgs}:

let
  evalConfig = import "${nixos}/lib/eval-config.nix";
  inherit (builtins) getAttr attrNames unsafeDiscardOutputDependency;
in
rec {
  generateConfigurations = network:
    pkgs.lib.mapAttrs (targetName: configuration:
      evalConfig {
        inherit nixpkgs;
        modules = configuration
        ++ [
          { key = "publish-infrastructure";
            services.disnix.enable = true;
            services.disnix.publishInfrastructure.enable = true;
            services.disnix.publishInfrastructure.enableAuthentication = true;
            networking.hostName = pkgs.lib.mkOverride 900 targetName;
          }
        ];
        extraArgs = { nodes = generateConfigurations network; };
      }
    ) network
  ;
  
  generateProfiles = configurations: targetProperty:
    map (targetName:
      let
        machine = getAttr targetName configurations;
        infrastructure = machine.config.services.disnix.infrastructure;
      in
      {
        profile = machine.config.system.build.toplevel.outPath;
        target = getAttr targetProperty infrastructure;
      }
    ) (attrNames configurations)
  ;
  
  generateActivationMappings = configurations: targetProperty:
    map (targetName:
      let
        machine = getAttr targetName configurations;
        infrastructure = machine.config.services.disnix.infrastructure;
      in
      { name = targetName;
        service = machine.config.system.build.toplevel.outPath;
        target = infrastructure;
        dependsOn = [];
        type = "nixos-configuration";
        inherit targetProperty;
      }
    ) (attrNames configurations)
  ;
  
  generateTargetPropertyList = configurations: targetProperty:
    map (targetName:
      let
        machine = getAttr targetName configurations;
        infrastructure = machine.config.services.disnix.infrastructure;
      in
      getAttr targetProperty infrastructure
    ) (attrNames configurations)
  ;

  generateManifest = network: targetProperty:
    let
      configurations = generateConfigurations network;
    in
    { profiles = generateProfiles configurations targetProperty;
      activation = generateActivationMappings configurations targetProperty;
      targets = generateTargetPropertyList configurations targetProperty;
    };

  generateDistributedDerivation = network: targetProperty:
    let
      configurations = generateConfigurations network;
    in
    map (targetName:
      let
        machine = getAttr targetName configurations;
        infrastructure = machine.config.services.disnix.infrastructure;
      in
      { derivation = unsafeDiscardOutputDependency (machine.config.system.build.toplevel.drvPath);
        target = getAttr targetProperty infrastructure;
      }
    ) (attrNames configurations)
  ;
}
