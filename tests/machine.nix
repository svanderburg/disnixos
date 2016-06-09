{disnix, dysnomia, disnixos}:
{config, pkgs, ...}:

{
  virtualisation.writableStore = true;
  virtualisation.memorySize = 2048;
  virtualisation.diskSize = 10240;
  virtualisation.pathsInNixDB = [ pkgs.stdenv pkgs.perlPackages.ArchiveCpio pkgs.busybox ];
  
  ids.gids = { disnix = 200; };
  users.extraGroups = [ { gid = 200; name = "disnix"; } ];
  
  services.dbus.enable = true;
  services.dbus.packages = [ disnix ];
  services.openssh.enable = true;
  
  systemd.services.ssh.restartIfChanged = false;
  
  systemd.services.disnix =
    { description = "Disnix server";

      wantedBy = [ "multi-user.target" ];
      after = [ "dbus.service" ];
      
      path = [ pkgs.nix pkgs.getopt disnix dysnomia ];
      environment = {
        HOME = "/root";
      };

      serviceConfig.ExecStart = "${disnix}/bin/disnix-service";
    };
  
  environment.systemPackages = [ pkgs.nix dysnomia disnix disnixos pkgs.hello pkgs.zip ];
}
