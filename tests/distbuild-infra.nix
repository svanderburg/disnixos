{nixpkgs, writeTextFile, openssh, dysnomia, disnix, disnixos}:

with import "${nixpkgs}/nixos/lib/testing-python.nix" { system = builtins.currentSystem; };

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
          "NIX_PATH=nixpkgs=${nixpkgs} SSH_OPTS='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no' disnixos-deploy-network ${logicalNetworkNix} ${physicalNetworkNix} --disable-disnix --build-on-targets"
      )

      # Check if zip is installed on the correct machine
      testtarget1.succeed("zip -h")
      testtarget2.fail("zip -h")

      # Check if hello is installed on the correct machine
      testtarget2.succeed("hello")
      testtarget1.fail("hello")
    '';
}
