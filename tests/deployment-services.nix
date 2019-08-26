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

      # Deploy a packages configuration and check whether they have been successfully installed
      $coordinator->mustSucceed("${env} disnixos-env -P ${manifestTests}/target-pkgs.nix -n ${physicalNetworkNix} --disable-disnix --no-infra-deployment");
      $testtarget1->mustSucceed("/nix/var/nix/profiles/disnix/default/bin/curl --version");
      $testtarget2->mustSucceed("/nix/var/nix/profiles/disnix/default/bin/strace -h");

      # Deploy a NixOS network and services in a network specified by a NixOS network expression simultaneously
      $coordinator->mustSucceed("${env} disnixos-env -s ${manifestTests}/services.nix -n ${physicalNetworkNix} -d ${manifestTests}/distribution.nix --disable-disnix --no-infra-deployment");

      # Use disnixos-query to see if the right services are installed on
      # the right target platforms. This test should succeed.
      $coordinator->mustSucceed("${env} disnixos-query -f xml ${physicalNetworkNix} > query.xml");

      $coordinator->mustSucceed("xmllint --xpath \"/profileManifestTargets/target[\@name='testtarget1']/profileManifest/services/service[name='testService1']/name\" query.xml");
      $coordinator->mustSucceed("xmllint --xpath \"/profileManifestTargets/target[\@name='testtarget2']/profileManifest/services/service[name='testService2']/name\" query.xml");
      $coordinator->mustSucceed("xmllint --xpath \"/profileManifestTargets/target[\@name='testtarget2']/profileManifest/services/service[name='testService3']/name\" query.xml");
    '';
}
