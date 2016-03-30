{nixpkgs, writeTextFile, runCommand, openssh, dysnomiaTarball, dysnomia, disnix, disnixos}:

with import "${nixpkgs}/nixos/lib/testing.nix" { system = builtins.currentSystem; };

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
      virtualisation.memorySize = 2048;
      virtualisation.diskSize = 10240;
      virtualisation.pathsInNixDB = [ pkgs.stdenv pkgs.perlPackages.ArchiveCpio pkgs.busybox ];
      
      ids.gids = { disnix = 200; };
      users.extraGroups = [ { gid = 200; name = "disnix"; } ];
      
      services.dbus.enable = true;
      services.dbus.packages = [ disnix ];
      services.openssh.enable = true;
      
      services.dysnomia = {
        enable = true;
      };
      
      services.mysql = {
        enable = true;
        package = pkgs.mysql;
        rootPassword = pkgs.writeTextFile { name = "mysqlpw"; text = "verysecret"; };
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
      
          path = [ pkgs.nix pkgs.getopt disnix config.services.dysnomia.package "/run/current-system/sw" ];
          environment = {
            HOME = "/root";
          };

          serviceConfig.ExecStart = "${disnix}/bin/disnix-service";
        };
    
        environment.systemPackages = [ config.services.dysnomia.package disnix disnixos ];
    };

  manifestTests = ./manifest;
  
  # TODO: properly refer to the Dysnomia module
  
  logicalNetworkNix = writeTextFile {
    name = "network-logical-dysnomia.nix";
  
    text = ''
      {
        testtarget1 = {pkgs, ...}:
      
        {
          imports = [ ${dysnomiaSrc}/dysnomia-module.nix ];
          
          services.dysnomia = {
            enable = true;
            
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
            rootPassword = pkgs.writeTextFile { name = "mysqlpw"; text = "verysecret"; };
          };
      
          services.postgresql = {
            enable = true;
            package = pkgs.postgresql;
          };
          
          environment.systemPackages = [ ${disnix} ];
        };
      
        testtarget2 = {pkgs, ...}:
        
        {
          imports = [ ${dysnomiaSrc}/dysnomia-module.nix ];
          
          services.mysql = {
            enable = true;
            package = pkgs.mysql;
            rootPassword = pkgs.writeTextFile { name = "mysqlpw"; text = "verysecret"; };
          };
      
          services.postgresql = {
            enable = true;
            package = pkgs.postgresql;
          };
          
          environment.systemPackages = [ ${disnix} ];
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
          
          services.dysnomia = {
            enable = true;
            
            # We have undeployed the databases
          };
          
          services.mysql = {
            enable = true;
            package = pkgs.mysql;
            rootPassword = pkgs.writeTextFile { name = "mysqlpw"; text = "verysecret"; };
          };
      
          services.postgresql = {
            enable = true;
            package = pkgs.postgresql;
          };
          
          environment.systemPackages = [ ${disnix} ];
        };
      
        testtarget2 = {pkgs, ...}:
        
        {
          imports = [ ${dysnomiaSrc}/dysnomia-module.nix ];
          
          services.mysql = {
            enable = true;
            package = pkgs.mysql;
            rootPassword = pkgs.writeTextFile { name = "mysqlpw"; text = "verysecret"; };
          };
      
          services.postgresql = {
            enable = true;
            package = pkgs.postgresql;
          };
          
          environment.systemPackages = [ ${disnix} ];
        };
      }
    '';
  };

  physicalNetworkNix = import ./generate-physical-network.nix { inherit writeTextFile nixpkgs; };
in
simpleTest {
  nodes = {
    coordinator = machine;
    testtarget1 = machine;
    testtarget2 = machine;
  };
  testScript =
    ''
      startAll;
      $coordinator->waitForJob("network-interfaces.target");
      $testtarget1->waitForJob("disnix");
      $testtarget2->waitForJob("disnix");
        
      # Initialise ssh stuff by creating a key pair for communication
      my $key=`${openssh}/bin/ssh-keygen -t dsa -f key -N ""`;
        
      $testtarget1->mustSucceed("mkdir -m 700 /root/.ssh");
      $testtarget1->copyFileFromHost("key.pub", "/root/.ssh/authorized_keys");

      $testtarget2->mustSucceed("mkdir -m 700 /root/.ssh");
      $testtarget2->copyFileFromHost("key.pub", "/root/.ssh/authorized_keys");
        
      $coordinator->mustSucceed("mkdir -m 700 /root/.ssh");
      $coordinator->copyFileFromHost("key", "/root/.ssh/id_dsa");
      $coordinator->mustSucceed("chmod 600 /root/.ssh/id_dsa");
        
      # Deploy the test NixOS network expression. This test should succeed.
      $coordinator->mustSucceed("NIX_PATH=nixpkgs=${nixpkgs} SSH_OPTS='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no' disnixos-deploy-network ${logicalNetworkNix} ${physicalNetworkNix} --disable-disnix");
    
      # Capture the state of the NixOS configurations
      $coordinator->mustSucceed("NIX_PATH=nixpkgs=${nixpkgs} SSH_OPTS='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no' disnixos-snapshot-network ${logicalNetworkNix} ${physicalNetworkNix} --disable-disnix");
      
      # Check if two nixos-configuration snapshots exist
      my $result = $coordinator->mustSucceed("dysnomia-snapshots --query-latest --container nixos-configuration");
      my @snapshots = split('\n', $result);
      
      if(scalar(@snapshots) == 2) {
          print "We have 2 nixos-configuration snapshots\n";
      } else {
          die "We should have 2 nixos-configuration snapshots!";
      }
      
      # Modify the state of the databases
      
      $testtarget1->mustSucceed("echo \"insert into test values ('Bye world');\" | mysql --user=root --password=verysecret -N testdb");
      $testtarget1->mustSucceed("echo \"insert into test values ('Bye world');\" | psql --file - testdb");
      
      # Remove all the remote snapshots and check if both the Disnix and NixOS
      # state dir have no snapshots
      $coordinator->mustSucceed("NIX_PATH=nixpkgs=${nixpkgs} SSH_OPTS='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no' disnixos-clean-snapshots --keep 0 ${logicalNetworkNix}");
      
      $result = $testtarget1->mustSucceed("DYSNOMIA_STATEDIR=/var/state/dysnomia dysnomia-snapshots --query-all");
      @snapshots = split('\n', $result);
      
      if(scalar(@snapshots) == 0) {
          print "We have 0 snapshots in the Disnix state directory\n";
      } else {
          die "We should have 0 snapshots in the Disnix state directory\n";
      }
      
      # TODO: make command that removes system-level snapshots
      #$result = $testtarget1->mustSucceed("DYSNOMIA_STATEDIR=/var/state/dysnomia-nixos dysnomia-snapshots --query-all");
      #@snapshots = split('\n', $result);
      
      #if(scalar(@snapshots) == 0) {
        #print "We have 0 snapshots in the NixOS state directory\n";
      #} else {
      #die "We should have 0 snapshots in the NixOS state directory\n";
      #}
      
      # Restore the state of the databases and check whether the modifications
      # are gone.
      
      $coordinator->mustSucceed("NIX_PATH=nixpkgs=${nixpkgs} SSH_OPTS='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no' disnixos-restore-network ${logicalNetworkNix2} ${physicalNetworkNix} --disable-disnix");
      
      $result = $testtarget1->mustSucceed("echo 'select * from test' | mysql --user=root --password=verysecret -N testdb");
      
      if($result =~ /Bye world/) {
          die "MySQL table should not contain: Bye world!\n";
      } else {
          print "MySQL does not contain: Bye world!\n";
      }
      
      $result = $testtarget1->mustSucceed("echo 'select * from test' | psql --file - testdb");
      
      if($result =~ /Bye world/) {
          die "PostgreSQL table should not contain: Bye world!\n";
      } else {
          print "PostgreSQL does not contain: Bye world!\n";
      }
      
      # Delete the state. Because no databases have been undeployed, they should be kept.
      $coordinator->mustSucceed("NIX_PATH=nixpkgs=${nixpkgs} SSH_OPTS='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no' disnixos-delete-network-state ${logicalNetworkNix2} ${physicalNetworkNix} --disable-disnix");
      
      $result = $testtarget1->mustSucceed("echo 'select * from test' | mysql --user=root --password=verysecret -N testdb");
      
      if($result =~ /Bye world/) {
          die "MySQL table should not contain: Bye world!\n";
      } else {
          print "MySQL does not contain: Bye world!\n";
      }
      
      $result = $testtarget1->mustSucceed("echo 'select * from test' | psql --file - testdb");
      
      if($result =~ /Bye world/) {
          die "PostgreSQL table should not contain: Bye world!\n";
      } else {
          print "PostgreSQL does not contain: Bye world!\n";
      }
      
      # Upgrade the test NixOS configuration with the databases undeployed.
      $coordinator->mustSucceed("NIX_PATH=nixpkgs=${nixpkgs} SSH_OPTS='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no' disnixos-deploy-network ${logicalNetworkNix2} ${physicalNetworkNix} --disable-disnix");
      
      # Delete the state. Because the databases were undeployed, they should have been removed.
      
      $coordinator->mustSucceed("NIX_PATH=nixpkgs=${nixpkgs} SSH_OPTS='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no' disnixos-delete-network-state ${logicalNetworkNix2} ${physicalNetworkNix} --disable-disnix");
      
      $testtarget1->mustFail("echo 'select * from test' | mysql --user=root --password=verysecret -N testdb");
      $testtarget1->mustFail("echo 'select * from test' | psql --file - testdb");
    '';
}
