{dysnomia, disnix, disnixos}:
{config, pkgs, ...}:

{
  virtualisation.writableStore = true;
  virtualisation.memorySize = 1024;
  virtualisation.diskSize = 10240;
  
  ids.gids = { disnix = 200; };
  users.extraGroups = [ { gid = 200; name = "disnix"; } ];
  
  services.dbus.enable = true;
  services.dbus.packages = [ disnix ];
  services.openssh.enable = true;
  
  jobs.ssh.restartIfChanged = false;
  
  jobs.disnix =
    { description = "Disnix server";

      wantedBy = [ "multi-user.target" ];
      after = [ "dbus.service" ];
      
      path = [ pkgs.nix disnix dysnomia ];
      
      environment = {
        HOME = "/root";
      };

      exec = "disnix-service";
    };
    
    environment.systemPackages = [ pkgs.stdenv pkgs.nix disnix disnixos pkgs.hello pkgs.zip pkgs.nixops
      pkgs.busybox pkgs.module_init_tools pkgs.perlPackages.ArchiveCpio # Upgrades fail without this, because it is needed to rebuild the NixOS configuration
    ];
}
