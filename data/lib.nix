{nixpkgs, nixos, pkgs}:

let
  evalConfig = import "${nixos}/lib/eval-config.nix";
  inherit (builtins) getAttr attrNames removeAttrs unsafeDiscardOutputDependency;
in
rec {

  /*
   * Takes a collection of NixOS network expressions and zips them into a list of
   * NixOS modules.
   *
   * Parameters:
   * networkFiles: A list of strings containing paths to NixOS network expressions
   * nixOpsModel: Indicates whether the configuration is a NixOps model so that certain attributes are ignored.
   *
   * Returns:
   * An attribute set in which the names refer to machine names and values to lists of NixOS modules
   */
  generateMergedNetwork = networkFiles: nixOpsModel:
    let
      networks = map (networkFile: import networkFile) networkFiles;
      mergedNetwork = pkgs.lib.zipAttrs networks;
    in
    if nixOpsModel then removeAttrs mergedNetwork [ "network" "resources" ] else mergedNetwork; # A NixOps model has a reserved network attributes that cannot be machines
  
  /*
   * Takes a merged network configuration and evaluates them producing a config
   * attribute for each of them.
   *
   * Parameters:
   * enableDisnix: Indicates whether Disnix must be enabled
   * nixOpsModel: Indicates whether we should use NixOps specific settings
   * useVMTesting: Indicates whether we should enable NixOS test instrumentation and VM settings
   * useBackdoor: Indicates whether we should enable the backdoor
   *
   * Returns:
   * An attribute set with evaluated machine configurationb properties
   */
  generateConfigurations = network: enableDisnix: nixOpsModel: useVMTesting: useBackdoor:
    pkgs.lib.mapAttrs (targetName: configuration:
      evalConfig {
        modules = configuration ++ [
          ./disnix-infrastructure-module.nix
        ] ++ [
          {
            key = "disnix-infrastructure";
            networking.hostName = pkgs.lib.mkOverride 900 targetName;
            disnixInfrastructure.enable = true;
            disnixInfrastructure.enableAuthentication = true;
          }
        ]
        ++ pkgs.lib.optional enableDisnix {
          key = "enable-disnix";
          services.disnix.enable = true;
        }
        ++ pkgs.lib.optionals useVMTesting [
          "${nixos}/modules/virtualisation/qemu-vm.nix"
          "${nixos}/modules/testing/test-instrumentation.nix"
        ]
        ++ pkgs.lib.optional useBackdoor {
          key = "backdoor";
          disnixInfrastructure.infrastructure.backdoor = "TCP:${targetName}:512";
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

  /*
   * Generates a list of NixOS system profiles mapped to target machines.
   *
   * Parameters:
   * configurations: An attribute set with evaluated configurations
   * targetProperty: Attribute from the infrastructure model that is used to connect to the Disnix interface
   *
   * Returns:
   * A list of attribute sets in which NixOS profiles are mapped to target machines
   */
  generateProfiles = configurations: targetProperty:
    map (targetName:
      let
        machine = getAttr targetName configurations;
        infrastructure = machine.config.disnixInfrastructure.infrastructure;
      in
      {
        profile = machine.config.system.build.toplevel.outPath;
        target = getAttr targetProperty infrastructure;
      }
    ) (attrNames configurations)
  ;
  
  /*
   * Generates a list of activation items specifying on which machine to activate a NixOS configuration.
   *
   * Parameters:
   * configurations: An attribute set with evaluated configurations
   * targetProperty: Attribute from the infrastructure model that is used to connect to the Disnix interface
   *
   * Returns:
   * A list of attribute sets representing activation items
   */
  generateActivationMappings = configurations: targetProperty:
    map (targetName:
      let
        machine = getAttr targetName configurations;
        infrastructure = machine.config.disnixInfrastructure.infrastructure;
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
  
  /*
   * Generates a list of machines that are involved in the deployment process.
   *
   * Parameters:
   * configurations: An attribute set with evaluated configurations
   * targetProperty: Attribute from the infrastructure model that is used to connect to the Disnix interface
   *
   * Returns:
   * A list of strings with connection attributes of each machine that is used
   */
  generateTargetPropertyList = configurations: targetProperty:
    map (targetName:
      let
        machine = getAttr targetName configurations;
        infrastructure = machine.config.disnixInfrastructure.infrastructure;
      in
      getAttr targetProperty infrastructure
    ) (attrNames configurations)
  ;

  /*
   * Generates a manifest file consisting of a profile mapping and
   * service activation mapping from the 3 Disnix models.
   *
   * Parameters:
   * network: An evaluated network with machine configurations
   * targetProperty: Attribute from the infrastructure model that is used to connect to the Disnix interface
   * enableDisnix: Indicates whether Disnix must be enabled
   * nixOpsModel: Indicates whether we should use NixOps specific settings
   * useVMTesting: Indicates whether we should enable NixOS test instrumentation and VM settings
   * useBackdoor: Indicates whether we should enable the backdoor
   *
   * Returns:
   * An attributeset which should be exported to XML representing the manifest
   */
  generateManifest = network: targetProperty: enableDisnix: nixOpsModel: useVMTesting: useBackdoor:
    let
      configurations = generateConfigurations network enableDisnix nixOpsModel useVMTesting useBackdoor;
    in
    { profiles = generateProfiles configurations targetProperty;
      activation = generateActivationMappings configurations targetProperty;
      targets = generateTargetPropertyList configurations targetProperty;
    };
  
  /*
   * Generates a distributed derivation file constisting of a mapping of store derivations
   * to machines from the 3 Disnix models.
   *
   * Parameters:
   * network: An evaluated network with machine configurations
   * targetProperty: Attribute from the infrastructure model that is used to connect to the Disnix interface
   * enableDisnix: Indicates whether Disnix must be enabled
   * nixOpsModel: Indicates whether we should use NixOps specific settings
   * useVMTesting: Indicates whether we should enable NixOS test instrumentation and VM settings
   * useBackdoor: Indicates whether we should enable the backdoor
   *
   * Returns: 
   * An attributeset which should be exported to XML representing the distributed derivation
   */
  generateDistributedDerivation = network: targetProperty: enableDisnix: nixOpsModel: useVMTesting: useBackdoor:
    let
      configurations = generateConfigurations network enableDisnix nixOpsModel useVMTesting useBackdoor;
    in
    map (targetName:
      let
        machine = getAttr targetName configurations;
        infrastructure = machine.config.disnixInfrastructure.infrastructure;
      in
      { derivation = unsafeDiscardOutputDependency (machine.config.system.build.toplevel.drvPath);
        target = getAttr targetProperty infrastructure;
      }
    ) (attrNames configurations)
  ;
}
