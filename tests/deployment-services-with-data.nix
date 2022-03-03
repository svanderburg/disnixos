{nixpkgs, writeTextFile, openssh, dysnomia, disnix, disnixos}:

with import "${nixpkgs}/nixos/lib/testing-python.nix" { system = builtins.currentSystem; };

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

      # Deploy a NixOS network and services including state
      coordinator.succeed(
          "${env} dysnomia=\"$(dirname $(readlink -f $(type -p dysnomia)))/..\" disnixos-env -s ${snapshotsTests}/services-state.nix -n ${physicalNetworkNix} -d ${snapshotsTests}/distribution-simple.nix --disable-disnix --no-infra-deployment"
      )

      # Check if the state is actually deployed
      result = testtarget1.succeed("cat /var/db/testService1/state")

      if result[:-1] == "0":
          print("result is: 0")
      else:
          raise Exception("result should be: 0, but it is: {}".format(result))

      result = testtarget2.succeed("cat /var/db/testService2/state")

      if result[:-1] == "0":
          print("result is: 0")
      else:
          raise Exception("result should be: 0, but it is: {}".format(result))

      # Modify the state

      testtarget1.succeed("echo 1 > /var/db/testService1/state")
      testtarget2.succeed("echo 2 > /var/db/testService2/state")

      # Redeploy the services by reversing their distribution
      coordinator.succeed(
          "${env} dysnomia=\"$(dirname $(readlink -f $(type -p dysnomia)))/..\" disnixos-env -s ${snapshotsTests}/services-state.nix -n ${physicalNetworkNix} -d ${snapshotsTests}/distribution-reverse.nix --disable-disnix --no-infra-deployment"
      )

      # Check if the state has been migrated correctly
      result = testtarget1.succeed("cat /var/db/testService2/state")

      if result[:-1] == "2":
          print("result is: 2")
      else:
          raise Exception("result should be: 2")

      result = testtarget2.succeed("cat /var/db/testService1/state")

      if result[:-1] == "1":
          print("result is: 1")
      else:
          raise Exception("result should be: 1")

      # Run the clean snapshots operation to wipe out all snapshots on the target
      # machines and check if they are really removed.

      coordinator.succeed(
          "${env} disnixos-clean-snapshots --keep 0 ${physicalNetworkNix}"
      )

      result = testtarget1.succeed(
          "dysnomia-snapshots --query-all --container wrapper --component testService1 | wc -l"
      )

      if int(result) == 0:
          print("result is: 0")
      else:
          raise Exception("result should be: 0, but it is: {}".format(result))

      result = testtarget2.succeed(
          "dysnomia-snapshots --query-all --container wrapper --component testService2 | wc -l"
      )

      if int(result) == 0:
          print("result is: 0")
      else:
          raise Exception("result should be: 0, but it is: {}".format(result))
    '';
}
