{nixpkgs, pkgs}:

let
  lib = import ./lib.nix {
    inherit nixpkgs pkgs;
  };

  inherit (builtins) attrNames getAttr hashString listToAttrs stringLength substring toXML unsafeDiscardStringContext;

  generateHash = {name, type, pkg, dependsOn}:
    unsafeDiscardStringContext (hashString "sha256" (toXML {
      inherit name type pkg dependsOn;
    }));
in
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

{network, targetProperty, clientInterface, enableDisnix, nixOpsModel, useVMTesting, useBackdoor, dysnomia, nixops}:

let
  configurations = lib.generateConfigurations {
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
}
