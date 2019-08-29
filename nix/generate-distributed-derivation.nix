{nixpkgs, pkgs}:

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
{network, targetProperty, clientInterface, enableDisnix, nixOpsModel, useVMTesting, useBackdoor, dysnomia, nixops}:

let
  inherit (builtins) getAttr unsafeDiscardOutputDependency;

  lib = import ./lib.nix {
    inherit nixpkgs pkgs;
  };

  configurations = lib.generateConfigurations {
    inherit network enableDisnix nixOpsModel useVMTesting useBackdoor dysnomia nixops;
  };

  getTargetProperty = targetProperty: target:
    if target ? targetProperty then getAttr (target.targetProperty) target
    else getAttr targetProperty target;
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
}
