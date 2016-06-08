{nixpkgs, writeTextFile, openssh, dysnomia, disnix, disnixos}:

with import "${nixpkgs}/nixos/lib/testing.nix" { system = builtins.currentSystem; };

let
  machine = import ./machine.nix { inherit dysnomia disnix disnixos; };
  manifestTests = ./manifest;
  
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
      
      # Deploy a NixOS network and services in a network specified by a NixOS network expression simultaneously
      $coordinator->mustSucceed("${env} disnixos-env -s ${manifestTests}/services.nix -n ${physicalNetworkNix} -d ${manifestTests}/distribution.nix --disable-disnix --no-infra-deployment --build-on-targets");
      
      # Use disnixos-query to see if the right services are installed on
      # the right target platforms. This test should succeed.
      my @lines = split('\n', $coordinator->mustSucceed("${env} disnixos-query ${physicalNetworkNix}"));
      
      if($lines[3] =~ /\-testService1/) {
          print "Found testService1 on disnix-query output line 3\n";
      } else {
          die "disnix-query output line 3 does not contain testService1!\n";
      }
      
      if($lines[7] =~ /\-testService2/) {
          print "Found testService2 on disnix-query output line 7\n";
      } else {
          die "disnix-query output line 7 does not contain testService2!\n";
      }
      
      if($lines[8] =~ /\-testService3/) {
          print "Found testService3 on disnix-query output line 8\n";
      } else {
          die "disnix-query output line 8 does not contain testService3!\n";
      }
    '';
}
