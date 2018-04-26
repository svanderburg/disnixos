{nixpkgs, writeTextFile, openssh, dysnomia, disnix, disnixos}:

with import "${nixpkgs}/nixos/lib/testing.nix" { system = builtins.currentSystem; };

let
  machine = import ./machine.nix { inherit dysnomia disnix disnixos; };
  
  logicalNetworkNix = import ./generate-logical-network.nix { inherit writeTextFile; };
  physicalNetworkNix = import ./generate-physical-network.nix { inherit nixpkgs writeTextFile; };
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
      my $key=`${openssh}/bin/ssh-keygen -t ecdsa -f key -N ""`;
      
      $testtarget1->mustSucceed("mkdir -m 700 /root/.ssh");
      $testtarget1->copyFileFromHost("key.pub", "/root/.ssh/authorized_keys");

      $testtarget2->mustSucceed("mkdir -m 700 /root/.ssh");
      $testtarget2->copyFileFromHost("key.pub", "/root/.ssh/authorized_keys");
      
      $coordinator->mustSucceed("mkdir -m 700 /root/.ssh");
      $coordinator->copyFileFromHost("key", "/root/.ssh/id_dsa");
      $coordinator->mustSucceed("chmod 600 /root/.ssh/id_dsa");
      
      # Deploy the test NixOS network expression. This test should succeed.
      $coordinator->mustSucceed("NIX_PATH=nixpkgs=${nixpkgs} SSH_OPTS='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no' disnixos-deploy-network ${logicalNetworkNix} ${physicalNetworkNix} --disable-disnix --build-on-targets");
      
      # Check if zip is installed on the correct machine
      $testtarget1->mustSucceed("zip -h");
      $testtarget2->mustFail("zip -h");
      
      # Check if hello is installed on the correct machine
      $testtarget2->mustSucceed("hello");
      $testtarget1->mustFail("hello");
    '';
}
