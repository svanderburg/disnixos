{writeTextFile, nixpkgs, disnix}:

writeTextFile {
  name = "network-physical.nix";
    
  text = ''
    let
      machine = {pkgs, ...}:
        
      {
        require = [
          "${nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
          "${nixpkgs}/nixos/modules/testing/test-instrumentation.nix"
        ];
        boot.loader.grub.enable = false;
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
        
        environment.systemPackages = [ "${disnix}" ];
        
        deployment.targetEnv = "none";
      };
    in
    {
      testtarget1 = machine;
      testtarget2 = machine;
    }
  '';
}
