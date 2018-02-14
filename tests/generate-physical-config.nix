{writeTextFile, nixpkgs, dysnomia, disnix}:

writeTextFile {
  name = "network-physical.nix";

  text = ''
    {
      server = {pkgs, ...}:

      {
        require = [
          "${nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
          "${nixpkgs}/nixos/modules/testing/test-instrumentation.nix"
        ];
        boot.loader.grub.enable = false;
        services.nixosManual.enable = false;
        services.dbus.enable = true;
        services.openssh.enable = true;
        networking.firewall.enable = false;

        # Ugly: Replicates assignIPAddresses from build-vms.nix.
        networking.interfaces.eth1.ip4 = [ {
          address = "192.168.1.2";
          prefixLength = 24;
        } ];

        # Create dummy Disnix job that does nothing. This prevents it from stopping.
        systemd.services.disnix =
          { description = "Disnix dummy server";

            wantedBy = [ "multi-user.target" ];
            restartIfChanged = false;
            script = "true";
          };

        environment.systemPackages = [ "${disnix}" "${dysnomia}" ];

        deployment.targetEnv = "none";
      };
    }
  '';
}
