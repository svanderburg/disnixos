{nixpkgs, pkgs}:

let
  evalConfig = import "${nixpkgs}/nixos/lib/eval-config.nix";
  inherit (builtins) getAttr removeAttrs;
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
}
