{nixpkgs, nixos, pkgs}:

let
  evalConfig = import "${nixos}/lib/eval-config.nix";
  inherit (builtins) getAttr attrNames removeAttrs unsafeDiscardOutputDependency;
in
rec {

  generateMergedNetwork = networkFiles: nixOpsModel:
    let
      networks = map (networkFile: import networkFile) networkFiles;
      mergedNetwork = pkgs.lib.zipAttrs networks;
    in
    if nixOpsModel then removeAttrs mergedNetwork [ "network" "resources" ] else mergedNetwork; # A NixOps model has a reserved network attributes that cannot be machines
  
  generateConfigurations = network: enableDisnix: nixOpsModel: useVMTesting: useBackdoor:
    pkgs.lib.mapAttrs (targetName: configuration:
      evalConfig {
        modules = configuration
        ++ pkgs.lib.optional enableDisnix {
          key = "enable-disnix";
          services.disnix.enable = true;
          services.disnix.publishInfrastructure.enable = true;
          services.disnix.publishInfrastructure.enableAuthentication = true;
          networking.hostName = pkgs.lib.mkOverride 900 targetName;
        }
        ++ pkgs.lib.optionals useVMTesting [
          "${nixos}/modules/virtualisation/qemu-vm.nix"
          "${nixos}/modules/testing/test-instrumentation.nix"
        ]
        ++ pkgs.lib.optional useBackdoor {
          key = "backdoor";
          services.disnix.infrastructure.backdoor = "TCP:${targetName}:512";
        }
        ++ pkgs.lib.optional nixOpsModel {
          key = "nixops-stuff";
          # Make NixOps's deployment.* options available.
          require = [ <nixops/options.nix> ];
          # Provide a default hostname and deployment target equal
          # to the attribute name of the machine in the model.
          deployment.targetHost = pkgs.lib.mkOverride 900 targetName;
          environment.checkConfigurationOptions = false; # We assume that NixOps has already checked it
        };
        extraArgs = { nodes = generateConfigurations network enableDisnix nixOpsModel useVMTesting useBackdoor; };
      }) network;

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

  generateManifest = network: targetProperty: enableDisnix: nixOpsModel: useVMTesting: useBackdoor:
    let
      configurations = generateConfigurations network enableDisnix nixOpsModel useVMTesting useBackdoor;
    in
    { profiles = generateProfiles configurations targetProperty;
      activation = generateActivationMappings configurations targetProperty;
      targets = generateTargetPropertyList configurations targetProperty;
    };

  generateDistributedDerivation = network: targetProperty: enableDisnix: nixOpsModel: useVMTesting: useBackdoor:
    let
      configurations = generateConfigurations network enableDisnix nixOpsModel useVMTesting useBackdoor;
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
