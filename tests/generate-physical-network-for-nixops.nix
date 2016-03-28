{writeTextFile, nixpkgs, disnix}:

writeTextFile {
  name = "network-physical.nix";
    
  text = ''
    let
      machine = {hostname}: {pkgs, ...}:
        
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
          address = if hostname == "testtarget1" then "192.168.1.2"
            else if hostname == "testtarget2" then "192.168.1.3"
            else throw "Unknown hostname: "+hostname;
          prefixLength = 24;
        } ];
        
        # Create dummy Disnix job that does nothing. This prevents it from stopping.
        systemd.services.disnix =
          { description = "Disnix dummy server";

            wantedBy = [ "multi-user.target" ];
            restartIfChanged = false;
            script = "true";
          };
        
        environment.systemPackages = [ "${disnix}" ];
        
        deployment.targetEnv = "none";
      };
    in
    {
      testtarget1 = machine { hostname = "testtarget1"; };
      testtarget2 = machine { hostname = "testtarget2"; };
    }
  '';
}
