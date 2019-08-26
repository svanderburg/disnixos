{nixpkgs, writeTextFile, openssh, dysnomia, disnix, disnixos}:

with import "${nixpkgs}/nixos/lib/testing.nix" { system = builtins.currentSystem; };

let
  machine = import ./machine.nix { inherit dysnomia disnix disnixos; };
  snapshotsTests = ./snapshots;

  physicalNetworkNix = import ./generate-physical-network.nix { inherit writeTextFile nixpkgs; };

  env = "DYSNOMIA_STATEDIR=/root/dysnomia NIX_PATH=nixpkgs=${nixpkgs} SSH_OPTS='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'";
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

      # Deploy a NixOS network and services including state
      $coordinator->mustSucceed("${env} dysnomia=\"\$(dirname \$(readlink -f \$(type -p dysnomia)))/..\" disnixos-env -s ${snapshotsTests}/services-state.nix -n ${physicalNetworkNix} -d ${snapshotsTests}/distribution-simple.nix --disable-disnix --no-infra-deployment");

      # Check if the state is actually deployed
      my $result = $testtarget1->mustSucceed("cat /var/db/testService1/state");

      if($result == 0) {
          print "result is: 0\n";
      } else {
          die "result should be: 0";
      }

      $result = $testtarget2->mustSucceed("cat /var/db/testService2/state");

      if($result == 0) {
          print "result is: 0\n";
      } else {
          die "result should be: 0";
      }

      # Modify the state

      $testtarget1->mustSucceed("echo 1 > /var/db/testService1/state");
      $testtarget2->mustSucceed("echo 2 > /var/db/testService2/state");

      # Redeploy the services by reversing their distribution
      $coordinator->mustSucceed("${env} dysnomia=\"\$(dirname \$(readlink -f \$(type -p dysnomia)))/..\" disnixos-env -s ${snapshotsTests}/services-state.nix -n ${physicalNetworkNix} -d ${snapshotsTests}/distribution-reverse.nix --disable-disnix --no-infra-deployment");

      # Check if the state has been migrated correctly
      $result = $testtarget1->mustSucceed("cat /var/db/testService2/state");

      if($result == 2) {
          print "result is: 2\n";
      } else {
          die "result should be: 2";
      }

      $result = $testtarget2->mustSucceed("cat /var/db/testService1/state");

      if($result == 1) {
          print "result is: 1\n";
      } else {
          die "result should be: 1";
      }

      # Run the clean snapshots operation to wipe out all snapshots on the target
      # machines and check if they are really removed.

      $coordinator->mustSucceed("${env} disnixos-clean-snapshots --keep 0 ${physicalNetworkNix}");

      $result = $testtarget1->mustSucceed("dysnomia-snapshots --query-all --container wrapper --component testService1 | wc -l");

      if($result == 0) {
          print "result is: 0\n";
      } else {
          die "result should be: 0, but it is: $result";
      }

      $result = $testtarget2->mustSucceed("dysnomia-snapshots --query-all --container wrapper --component testService2 | wc -l");

      if($result == 0) {
          print "result is: 0\n";
      } else {
          die "result should be: 0, but it is: $result";
      }
    '';
}
