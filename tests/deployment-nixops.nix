{nixpkgs, writeTextFile, openssh, dysnomia, disnix, disnixos}:

with import "${nixpkgs}/nixos/lib/testing.nix" { system = builtins.currentSystem; };

let
  machine = import ./machine-with-nixops.nix { inherit dysnomia disnix disnixos; };
  manifestTests = ./manifest;

  logicalNetworkNix = import ./generate-logical-network.nix { inherit writeTextFile; };
  physicalNetworkNix = import ./generate-physical-network-for-nixops.nix { inherit writeTextFile nixpkgs disnix; };

  env = "NIX_PATH=nixpkgs=${nixpkgs}:nixos=${nixpkgs}/nixos ";
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
      $testtarget1->waitForJob("sshd");
      $testtarget2->waitForJob("sshd");

      # Initialise ssh stuff by creating a key pair for communication
      my $key=`${openssh}/bin/ssh-keygen -t ecdsa -f key -N ""`;

      $testtarget1->mustSucceed("mkdir -m 700 /root/.ssh");
      $testtarget1->copyFileFromHost("key.pub", "/root/.ssh/authorized_keys");

      $testtarget2->mustSucceed("mkdir -m 700 /root/.ssh");
      $testtarget2->copyFileFromHost("key.pub", "/root/.ssh/authorized_keys");

      $coordinator->mustSucceed("mkdir -m 700 /root/.ssh");
      $coordinator->copyFileFromHost("key", "/root/.ssh/id_dsa");
      $coordinator->mustSucceed("chmod 600 /root/.ssh/id_dsa");

      # Test SSH connectivity
      $coordinator->succeed("ssh -o StrictHostKeyChecking=no -v testtarget1 ls /");
      $coordinator->succeed("ssh -o StrictHostKeyChecking=no -v testtarget2 ls /");

      # Deploy infrastructure with NixOps
      $coordinator->mustSucceed("nixops create ${logicalNetworkNix} ${physicalNetworkNix}");
      $coordinator->mustSucceed("${env} nixops deploy");

      # Deploy services with disnixos-env
      $coordinator->mustSucceed("${env} disnixos-env -s ${manifestTests}/services.nix -n ${logicalNetworkNix} -n ${physicalNetworkNix} -d ${manifestTests}/distribution.nix --use-nixops");

      # Use disnixos-query to see if the right services are installed on
      # the right target platforms. This test should succeed.
      $coordinator->mustSucceed("${env} disnixos-query -f xml ${physicalNetworkNix} --use-nixops > query.xml");

      $coordinator->mustSucceed("xmllint --xpath \"/profileManifestTargets/target[\@name='testtarget1']/profileManifest/services/service[name='testService1']/name\" query.xml");
      $coordinator->mustSucceed("xmllint --xpath \"/profileManifestTargets/target[\@name='testtarget2']/profileManifest/services/service[name='testService2']/name\" query.xml");
      $coordinator->mustSucceed("xmllint --xpath \"/profileManifestTargets/target[\@name='testtarget2']/profileManifest/services/service[name='testService3']/name\" query.xml");
    '';
}
