{disnix, dysnomia, disnixos}:
{config, pkgs, lib, ...}:

{
  virtualisation = {
    writableStore = true;
    memorySize = 16384;
    diskSize = 40960;
    additionalPaths = [ pkgs.stdenv pkgs.stdenvNoCC ];
  };

  ids.gids = { disnix = 200; };
  users.extraGroups = {
    disnix = { gid = 200; };
  };

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

  # We can't download any substitutes in a test environment. To make tests
  # faster, we disable substitutes so that Nix does not waste any time by
  # attempting to download them.
  nix.settings = {
    substituters = lib.mkForce [];
    hashed-mirrors = null;
    connect-timeout = 1;
  };

  environment.systemPackages = [ pkgs.nix dysnomia disnix disnixos pkgs.hello pkgs.zip pkgs.libxml2 ];
  environment.variables.DISNIX_REMOTE_CLIENT = "disnix-client";

  # Add all dependencies that allow rebuilds and deploying NixOS without a network connection
  system.extraDependencies = [
    pkgs.stdenv
    pkgs.busybox
    pkgs.perlPackages.ArchiveCpio
    pkgs.e2fsprogs

    pkgs.util-linux
    pkgs.texinfo
    pkgs.xorg.lndir
    pkgs.getconf
    pkgs.desktop-file-utils
  ]
  ++ pkgs.brotli.all
  ++ pkgs.kmod.all
  ++ pkgs.libarchive.all
  ++ pkgs.libxml2.all
  ++ pkgs.libxslt.all;

  system.includeBuildDependencies = true;
}
