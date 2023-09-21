{dysnomia, disnix, disnixos}:
{config, pkgs, ...}:

{
  virtualisation = {
    writableStore = true;
    memorySize = 16384;
    diskSize = 10240;
    additionalPaths = [ pkgs.stdenv pkgs.stdenvNoCC ];
  };

  ids.gids = { disnix = 200; };
  users.extraGroups = {
    disnix = { gid = 200; };
  };
  networking.firewall.enable = false;

  services.dbus.enable = true;
  services.dbus.packages = [ disnix ];
  services.openssh.enable = true;

  #systemd.services.ssh.restartIfChanged = false;

  systemd.services.disnix =
    { description = "Disnix server";

      wantedBy = [ "multi-user.target" ];
      after = [ "dbus.service" ];

      path = [ pkgs.nix disnix dysnomia ];

      environment = {
        HOME = "/root";
      };

      serviceConfig.ExecStart = "${disnix}/bin/disnix-service";
    };

  # We can't download any substitutes in a test environment. To make tests
  # faster, we disable substitutes so that Nix does not waste any time by
  # attempting to download them.
  nix.extraOptions = ''
    substitute = false
  '';

  nixpkgs.config.permittedInsecurePackages = [
    "python-2.7.18.6"
    "python2.7-certifi-2021.10.8"
    "python2.7-pyjwt-1.7.1"
    "openssl-1.1.1v"
  ];

  environment.systemPackages = [ pkgs.nix dysnomia disnix disnixos pkgs.hello pkgs.zip pkgs.nixops pkgs.libxml2 ];
  environment.variables.DISNIX_REMOTE_CLIENT = "disnix-client";

  system.extraDependencies = [
    pkgs.stdenv
    pkgs.busybox
    pkgs.perlPackages.ArchiveCpio

    pkgs.util-linux
    pkgs.texinfo
    pkgs.xorg.lndir
    pkgs.getconf
    pkgs.desktop-file-utils
  ]
  ++ pkgs.coreutils.all
  ++ pkgs.libxml2.all
  ++ pkgs.libxslt.all;
}
