{nixpkgs, writeTextFile, openssh, dysnomia, disnix, disnixos}:

with import "${nixpkgs}/nixos/lib/testing-python.nix" { system = builtins.currentSystem; };

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
      import subprocess

      start_all()

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

      # Deploy a packages configuration and check whether they have been successfully installed
      coordinator.succeed(
          "${env} disnixos-env -P ${manifestTests}/target-pkgs.nix -n ${physicalNetworkNix} --disable-disnix --no-infra-deployment"
      )
      testtarget1.succeed("/nix/var/nix/profiles/disnix/default/bin/curl --version")
      testtarget2.succeed("/nix/var/nix/profiles/disnix/default/bin/strace -h")

      # Deploy a NixOS network and services in a network specified by a NixOS network expression simultaneously
      coordinator.succeed(
          "${env} disnixos-env -s ${manifestTests}/services.nix -n ${physicalNetworkNix} -d ${manifestTests}/distribution.nix --disable-disnix --no-infra-deployment"
      )

      # Use disnixos-query to see if the right services are installed on
      # the right target platforms. This test should succeed.
      coordinator.succeed(
          "${env} disnixos-query -f xml ${physicalNetworkNix} > query.xml"
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

      # Undeploy the entire system and check if no services are on the target machines
      coordinator.succeed(
          "${env} disnixos-env --undeploy -n ${physicalNetworkNix} --disable-disnix --no-infra-deployment"
      )
      coordinator.succeed(
          "${env} disnixos-query -f xml ${physicalNetworkNix} > query.xml"
      )

      coordinator.fail(
          "xmllint --xpath \"/profileManifestTargets/target[@name='testtarget1']/profileManifest/services/*\" query.xml"
      )
      coordinator.fail(
          "xmllint --xpath \"/profileManifestTargets/target[@name='testtarget2']/profileManifest/services/*\" query.xml"
      )
    '';
}
