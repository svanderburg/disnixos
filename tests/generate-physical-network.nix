{writeTextFile, nixpkgs}:

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
        disnixInfrastructure.enable = true;
        disnixInfrastructure.infrastructure.hostname = hostname;
        services.nixosManual.enable = false;
        services.dbus.enable = true;
        services.openssh.enable = true;
        
        # Create dummy Disnix job that does nothing. This prevents it from stopping.
        jobs.disnix =
          { description = "Disnix dummy server";
            wantedBy = [ "multi-user.target" ];
            restartIfChanged = false;
            script = "true";
          };
      };
    in
    {
      testtarget1 = machine { hostname = "testtarget1"; };
      testtarget2 = machine { hostname = "testtarget2"; };
    }
  '';
}
