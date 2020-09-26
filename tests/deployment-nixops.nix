{nixpkgs, writeTextFile, openssh, dysnomia, disnix, disnixos}:

with import "${nixpkgs}/nixos/lib/testing-python.nix" { system = builtins.currentSystem; };

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
      start_all()

      coordinator.wait_for_job("network-interfaces.target")
      testtarget1.wait_for_job("disnix")
      testtarget2.wait_for_job("disnix")
      testtarget1.wait_for_job("sshd")
      testtarget2.wait_for_job("sshd")

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

      # Test SSH connectivity
      coordinator.succeed("ssh -o StrictHostKeyChecking=no -v testtarget1 ls /")
      coordinator.succeed("ssh -o StrictHostKeyChecking=no -v testtarget2 ls /")

      # Deploy infrastructure with NixOps
      coordinator.succeed(
          "nixops create ${logicalNetworkNix} ${physicalNetworkNix}"
      )
      coordinator.succeed(
          "${env} nixops deploy"
      )

      # Deploy services with disnixos-env
      coordinator.succeed(
          "${env} disnixos-env -s ${manifestTests}/services.nix -n ${logicalNetworkNix} -n ${physicalNetworkNix} -d ${manifestTests}/distribution.nix --use-nixops"
      )

      # Use disnixos-query to see if the right services are installed on
      # the right target platforms. This test should succeed.
      coordinator.succeed(
          "${env} disnixos-query -f xml ${physicalNetworkNix} --use-nixops > query.xml"
      )

      coordinator.succeed(
          "xmllint --xpath \"/profileManifestTargets/target[@name='testtarget1']/profileManifest/services/service[name='testService1']/name\" query.xml"
      )
      coordinator.succeed(
          "xmllint --xpath \"/profileManifestTargets/target[@name='testtarget2']/profileManifest/services/service[name='testService2']/name\" query.xml"
      )
      coordinator.succeed(
          "xmllint --xpath \"/profileManifestTargets/target[@name='testtarget2']/profileManifest/services/service[name='testService3']/name\" query.xml"
      )
    '';
}
