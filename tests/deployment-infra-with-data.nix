{nixpkgs, writeTextFile, runCommand, openssh, dysnomiaTarball, dysnomia, disnix, disnixos}:

with import "${nixpkgs}/nixos/lib/testing-python.nix" { system = builtins.currentSystem; };

let
  dysnomiaSrc = runCommand "dysnomia-sources" {} ''
    tar --no-same-owner --no-same-permissions -xf $(find ${dysnomiaTarball} -name \*.tar.gz)
    mv dysnomia-* $out
  '';
  machine =
    {config, pkgs, ...}:

    {
      imports = [ "${dysnomiaSrc}/dysnomia-module.nix" ];

      virtualisation.writableStore = true;
      virtualisation.memorySize = 8192;
      virtualisation.diskSize = 10240;

      ids.gids = { disnix = 200; };
      users.extraGroups = {
        disnix = { gid = 200; };
      };

      dysnomiaTest = {
        enable = true;
        enableAuthentication = true;
      };

      services.dbus.enable = true;
      services.dbus.packages = [ disnix ];
      services.openssh.enable = true;

      services.mysql = {
        enable = true;
        package = pkgs.mysql;
      };

      services.postgresql = {
        enable = true;
        package = pkgs.postgresql;
      };

      systemd.services.sshd.restartIfChanged = false;

      systemd.services.disnix =
        { description = "Disnix server";

          wantedBy = [ "multi-user.target" ];
          after = [ "dbus.service" ];

          path = [ pkgs.nix pkgs.getopt disnix config.dysnomiaTest.package "/run/current-system/sw" ];
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

      environment.systemPackages = [ config.dysnomiaTest.package disnix disnixos ];

      system.extraDependencies = [
        pkgs.stdenv
        pkgs.busybox
        pkgs.module_init_tools
        pkgs.perlPackages.ArchiveCpio

        pkgs.utillinux
        pkgs.texinfo
        pkgs.xlibs.lndir
        pkgs.getconf
        pkgs.desktop-file-utils
      ]
      ++ pkgs.libxml2.all
      ++ pkgs.libxslt.all;
    };

  manifestTests = ./manifest;

  logicalNetworkNix = writeTextFile {
    name = "network-logical-dysnomia.nix";

    text = ''
      {
        testtarget1 = {pkgs, ...}:

        {
          imports = [ ${dysnomiaSrc}/dysnomia-module.nix ];

          dysnomiaTest = {
            enable = true;
            enableAuthentication = true;

            components = {
              mysql-database = {
                testdb = pkgs.stdenv.mkDerivation {
                  name = "testdb";
                  buildCommand = '''
                    mkdir -p $out/mysql-databases
                    cat > $out/mysql-databases/testdb.sql <<EOF
                    create table test
                    ( foo    varchar(255)    not null,
                      primary key(foo));
                    EOF
                  ''';
                };
              };

              postgresql-database = {
                testdb = pkgs.stdenv.mkDerivation {
                  name = "testdb";
                  buildCommand = '''
                    mkdir -p $out/postgresql-databases
                    cat > $out/postgresql-databases/testdb.sql <<EOF
                    create table test
                    ( foo    varchar(255)   not null,
                      primary key(foo));
                    EOF
                  ''';
                };
              };
            };
          };

          services.mysql = {
            enable = true;
            package = pkgs.mysql;
          };

          services.postgresql = {
            enable = true;
            package = pkgs.postgresql;
          };

          environment.systemPackages = [ (builtins.storePath ${disnix}) ];
        };

        testtarget2 = {pkgs, ...}:

        {
          imports = [ ${dysnomiaSrc}/dysnomia-module.nix ];

          services.mysql = {
            enable = true;
            package = pkgs.mysql;
          };

          services.postgresql = {
            enable = true;
            package = pkgs.postgresql;
          };

          environment.systemPackages = [ (builtins.storePath ${disnix}) ];
        };
      }
    '';
  };

  logicalNetworkNix2 = writeTextFile {
    name = "network-logical-dysnomia.nix";

    text = ''
      {
        testtarget1 = {pkgs, ...}:

        {
          imports = [ ${dysnomiaSrc}/dysnomia-module.nix ];

          dysnomiaTest = {
            enable = true;
            enableAuthentication = true;
            # We have undeployed the databases
          };

          services.mysql = {
            enable = true;
            package = pkgs.mysql;
          };

          services.postgresql = {
            enable = true;
            package = pkgs.postgresql;
          };

          environment.systemPackages = [ (builtins.storePath ${disnix}) ];
        };

        testtarget2 = {pkgs, ...}:

        {
          imports = [ ${dysnomiaSrc}/dysnomia-module.nix ];

          services.mysql = {
            enable = true;
            package = pkgs.mysql;
          };

          services.postgresql = {
            enable = true;
            package = pkgs.postgresql;
          };

          environment.systemPackages = [ (builtins.storePath ${disnix}) ];
        };
      }
    '';
  };

  physicalNetworkNix = import ./generate-physical-network.nix { inherit writeTextFile nixpkgs; };

  env = "NIX_PATH=nixpkgs=${nixpkgs} SSH_OPTS='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'";
in
simpleTest {
  nodes = {
    coordinator = machine;
    testtarget1 = machine;
    testtarget2 = machine;
  };
  testScript =
    ''
      import subprocess

      start_all()

      coordinator.wait_for_unit("network-interfaces.target")
      testtarget1.wait_for_unit("disnix")
      testtarget2.wait_for_unit("disnix")

      # Initialise ssh stuff by creating a key pair for communication
      key = subprocess.check_output(
          '${pkgs.openssh}/bin/ssh-keygen -t ecdsa -f key -N ""',
          shell=True,
      )

      testtarget1.succeed("mkdir -m 700 /root/.ssh")
      testtarget1.copy_from_host("key.pub", "/root/.ssh/authorized_keys")

      testtarget2.succeed("mkdir -m 700 /root/.ssh")
      testtarget2.copy_from_host("key.pub", "/root/.ssh/authorized_keys")

      coordinator.succeed("mkdir -m 700 /root/.ssh")
      coordinator.copy_from_host("key", "/root/.ssh/id_dsa")
      coordinator.succeed("chmod 600 /root/.ssh/id_dsa")

      # Deploy the test NixOS network expression. This test should succeed.
      coordinator.succeed(
          "${env} disnixos-deploy-network ${logicalNetworkNix} ${physicalNetworkNix} --disable-disnix"
      )

      # Capture the state of the NixOS configurations
      coordinator.succeed(
          "${env} disnixos-snapshot-network ${logicalNetworkNix} ${physicalNetworkNix} --disable-disnix"
      )

      # Check if two nixos-configuration snapshots exist
      result = coordinator.succeed(
          "dysnomia-snapshots --query-latest --container nixos-configuration"
      )
      snapshots = result.split("\n")

      if len(snapshots[:-1]) == 2:
          print("We have 2 nixos-configuration snapshots")
      else:
          raise Exception("We should have 2 nixos-configuration snapshots!")

      # Modify the state of the databases

      testtarget1.succeed("echo \"insert into test values ('Bye world');\" | mysql -N testdb")
      testtarget1.succeed(
          "echo \"insert into test values ('Bye world');\" | su postgres -s /bin/sh -c 'psql --file - testdb'"
      )

      # Remove all the remote snapshots and check if both the Disnix and NixOS
      # state dir have no snapshots
      coordinator.succeed(
          "${env} disnixos-clean-snapshots --keep 0 ${logicalNetworkNix}"
      )

      result = testtarget1.succeed(
          "DYSNOMIA_STATEDIR=/var/state/dysnomia dysnomia-snapshots --query-all"
      )
      snapshots = result.split("\n")

      if len(snapshots[:-1]) == 0:
          print("We have 0 snapshots in the Disnix state directory")
      else:
          raise Exception("We should have 0 snapshots in the Disnix state directory")

      # TODO: make command that removes system-level snapshots
      # result = testtarget1.succeed("DYSNOMIA_STATEDIR=/var/state/dysnomia-nixos dysnomia-snapshots --query-all")
      # snapshots = result.split("\n")

      # if len(snapshots) == 0:
      #     print("We have 0 snapshots in the NixOS state directory")
      # else:
      #     raise Exception("We should have 0 snapshots in the NixOS state directory")

      # Restore the state of the databases and check whether the modifications
      # are gone.

      coordinator.succeed(
          "${env} disnixos-restore-network ${logicalNetworkNix2} ${physicalNetworkNix} --disable-disnix"
      )

      result = testtarget1.succeed("echo 'select * from test' | mysql -N testdb")

      if "Bye world" in result:
          raise Exception("MySQL table should not contain: Bye world!")
      else:
          print("MySQL does not contain: Bye world!")

      result = testtarget1.succeed(
          "echo 'select * from test' | su postgres -s /bin/sh -c 'psql --file - testdb'"
      )

      if "Bye world" in result:
          raise Exception("PostgreSQL table should not contain: Bye world!")
      else:
          print("PostgreSQL does not contain: Bye world!")

      # Delete the state. Because no databases have been undeployed, they should be kept.
      coordinator.succeed(
          "${env} disnixos-delete-network-state ${logicalNetworkNix2} ${physicalNetworkNix} --disable-disnix"
      )

      result = testtarget1.succeed("echo 'select * from test' | mysql -N testdb")

      if "Bye world" in result:
          raise Exception("MySQL table should not contain: Bye world!")
      else:
          print("MySQL does not contain: Bye world!")

      result = testtarget1.succeed(
          "echo 'select * from test' | su postgres -s /bin/sh -c 'psql --file - testdb'"
      )

      if "Bye world" in result:
          raise Exception("PostgreSQL table should not contain: Bye world!")
      else:
          print("PostgreSQL does not contain: Bye world!")

      # Upgrade the test NixOS configuration with the databases undeployed.
      coordinator.succeed(
          "${env} disnixos-deploy-network ${logicalNetworkNix2} ${physicalNetworkNix} --disable-disnix"
      )

      # Delete the state. Because the databases were undeployed, they should have been removed.

      coordinator.succeed(
          "${env} disnixos-delete-network-state ${logicalNetworkNix2} ${physicalNetworkNix} --disable-disnix"
      )

      testtarget1.fail("echo 'select * from test' | mysql -N testdb")
      testtarget1.fail(
          "echo 'select * from test' | su postgres -s /bin/sh -c 'psql --file - testdb'"
      )
    '';
}
