{nixpkgs, pkgs}:

let
  evalConfig = import "${nixpkgs}/nixos/lib/eval-config.nix";
  inherit (builtins) baseNameOf getAttr attrNames removeAttrs unsafeDiscardOutputDependency unsafeDiscardStringContext hashString toXML listToAttrs stringLength substring;
in
rec {
  /**
   * Fetches the key value that is used to refer to a target machine.
   * If a target defines a 'targetProperty' then the corresponding attribute
   * is used. If no targetProperty is provided by the target, then the global
   * targetProperty is used.
   *
   * Parameters:
   * targetProperty: Attribute from the infrastructure model that is used to connect to the Disnix interface
   * target: An attributeset containing properties of a target machine
   *
   * Returns
   * A string containing the key value
   */
  getTargetProperty = targetProperty: target:
    if target ? targetProperty then getAttr (target.targetProperty) target
    else getAttr targetProperty target
  ;

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
  generateMergedNetwork = {networkFiles, nixOpsModel}:
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
   * dysnomia: Path to Dysnomia
   * nixops: Path to NixOps
   *
   * Returns:
   * An attribute set with evaluated machine configuration properties
   */
  generateConfigurations = {network, enableDisnix, nixOpsModel, useVMTesting, useBackdoor, dysnomia, nixops}:
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
            disnixInfrastructure.generateContainersExpr = "${dysnomia}/share/dysnomia/generate-containers.nix";
          }
        ]
        ++ pkgs.lib.optional enableDisnix {
          key = "enable-disnix";
          services.disnix.enable = true;
        }
        ++ pkgs.lib.optionals useVMTesting [
          "${nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
          "${nixpkgs}/nixos/modules/testing/test-instrumentation.nix"
        ]
        ++ pkgs.lib.optional useBackdoor {
          key = "backdoor";
          disnixInfrastructure.properties.backdoor = "TCP:${targetName}:512";
        }
        ++ pkgs.lib.optional nixOpsModel {
          key = "nixops-stuff";
          # Make NixOps's deployment.* options available.
          require = [ "${nixops}/share/nix/nixops/options.nix" ];
          # Provide a default hostname and deployment target equal
          # to the attribute name of the machine in the model.
          deployment.targetHost = pkgs.lib.mkOverride 900 targetName;
          environment.checkConfigurationOptions = false; # We assume that NixOps has already checked it
        };
        extraArgs = {
          nodes = generateConfigurations {
            inherit network enableDisnix nixOpsModel useVMTesting useBackdoor dysnomia nixops;
          };
        };
      }) network;

  generateHash = {name, type, pkg, dependsOn}:
    unsafeDiscardStringContext (hashString "sha256" (toXML {
      inherit name type pkg dependsOn;
    }));

  /*
   * Generates a manifest file consisting of a profile mapping and
   * service activation mapping from the 3 Disnix models.
   *
   * Parameters:
   * network: An evaluated network with machine configurations
   * targetProperty: Attribute from the infrastructure model that is used to connect to the Disnix interface
   * clientInterface: Path to the executable used to connect to the Disnix interface
   * enableDisnix: Indicates whether Disnix must be enabled
   * nixOpsModel: Indicates whether we should use NixOps specific settings
   * useVMTesting: Indicates whether we should enable NixOS test instrumentation and VM settings
   * useBackdoor: Indicates whether we should enable the backdoor
   * dysnomia: Path to Dysnomia
   * nixops: Path to NixOps
   *
   * Returns:
   * An attributeset which should be exported to XML representing the manifest
   */
  generateManifest = {network, targetProperty, clientInterface, enableDisnix, nixOpsModel, useVMTesting, useBackdoor, dysnomia, nixops}:
    let
      configurations = generateConfigurations {
        inherit network enableDisnix nixOpsModel useVMTesting useBackdoor dysnomia nixops;
      };
    in
    {
      profiles = pkgs.lib.mapAttrs (targetName: machine: machine.config.system.build.toplevel.outPath) configurations;

      services = listToAttrs (map (targetName:
        let
          machine = getAttr targetName configurations;
          serviceConfig = {
            name = targetName;
            pkg = machine.config.system.build.toplevel.outPath;
            dependsOn = {};
            type = "nixos-configuration";
          };
        in
        { name = generateHash serviceConfig;
          value = serviceConfig;
        }
      ) (attrNames configurations));

      serviceMappings = map (targetName:
        let
          machine = getAttr targetName configurations;
        in
        { service = generateHash {
            name = targetName;
            pkg = machine.config.system.build.toplevel.outPath;
            dependsOn = {};
            type = "nixos-configuration";
          };
          container = "nixos-configuration";
          target = targetName;
        }
      ) (attrNames configurations);

      snapshotMappings = map (targetName:
        let
          machine = getAttr targetName configurations;
          pkg = machine.config.system.build.toplevel.outPath;
        in
        { service = generateHash {
            name = targetName;
            dependsOn = {};
            type = "nixos-configuration";
            inherit pkg;
          };
          component = substring 33 (stringLength pkg) (baseNameOf pkg);
          container = "nixos-configuration";
          target = targetName;
        }
      ) (attrNames configurations);

      infrastructure = pkgs.lib.mapAttrs (targetName: machine:
        let
          machine = getAttr targetName configurations;
        in
        {
          inherit targetProperty clientInterface;
          numOfCores = 1;
        } // machine.config.disnixInfrastructure.infrastructure
      ) configurations;
    };

  /*
   * Generates a distributed derivation file constisting of a mapping of store derivations
   * to machines from the 3 Disnix models.
   *
   * Parameters:
   * network: An evaluated network with machine configurations
   * targetProperty: Attribute from the infrastructure model that is used to connect to the Disnix interface
   * clientInterface: Path to the executable used to connect to the Disnix interface
   * enableDisnix: Indicates whether Disnix must be enabled
   * nixOpsModel: Indicates whether we should use NixOps specific settings
   * useVMTesting: Indicates whether we should enable NixOS test instrumentation and VM settings
   * useBackdoor: Indicates whether we should enable the backdoor
   * dysnomia: Path to Dysnomia
   * nixops: Path to NixOps
   *
   * Returns:
   * An attributeset which should be exported to XML representing the distributed derivation
   */
  generateDistributedDerivation = {network, targetProperty, clientInterface, enableDisnix, nixOpsModel, useVMTesting, useBackdoor, dysnomia, nixops}:
    let
      configurations = generateConfigurations {
        inherit network enableDisnix nixOpsModel useVMTesting useBackdoor dysnomia nixops;
      };
    in
    {
      derivationMappings = pkgs.lib.mapAttrs (targetName: machine:
        let
          infrastructure = machine.config.disnixInfrastructure.infrastructure;
        in
        unsafeDiscardOutputDependency (machine.config.system.build.toplevel.drvPath)
      ) configurations;

      interfaces = pkgs.lib.mapAttrs (targetName: machine:
        let
          infrastructure = machine.config.disnixInfrastructure.infrastructure;
        in
        { targetAddress = getTargetProperty targetProperty infrastructure;
          clientInterface = if infrastructure ? clientInterface then infrastructure.clientInterface else clientInterface;
        }
      ) configurations;
    };
}
