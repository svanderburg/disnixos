{network, testScript, manifestFile, disnix, socat, concatMapStrings, dysnomiaStateDir ? "/tmp/shared/dysnomia"}:

let
  firstTargetName = builtins.head (builtins.attrNames network);
in
''
  # fmt: off
  start_all()
'' + concatMapStrings (targetName: ''
  ${targetName}.wait_for_unit("network.target")
  ${targetName}.wait_for_unit("disnix.service")
  ${targetName}.succeed("iptables -I INPUT -p tcp --dport 512 -j ACCEPT || true")
  pid = ${targetName}.succeed(
      "${socat}/bin/socat tcp-listen:512,fork exec:/bin/sh & echo -n $!"
  )
  ${targetName}.succeed(
      'while [ "$(ps -p {} | grep socat)" = "" ]; do sleep 0.5; done'.format(pid)
  )
  ${targetName}.succeed("mkdir -p /var/state/dysnomia")
  ${targetName}.succeed(
      'if [ -d "${dysnomiaStateDir}/snapshots" ]; then ln -s ${dysnomiaStateDir}/snapshots /var/state/dysnomia/snapshots; fi'
  )
  ${targetName}.succeed(
      'if [ -d "${dysnomiaStateDir}/generations" ]; then ln -s ${dysnomiaStateDir}/generations /var/state/dysnomia/generations; fi'
  )
'') (builtins.attrNames network) +
''

  ${firstTargetName}.succeed(
      "${disnix}/bin/disnix-activate --no-upgrade ${manifestFile}"
  )
  ${firstTargetName}.succeed(
      "${disnix}/bin/disnix-restore --no-upgrade ${manifestFile}"
  )

  # fmt: on
  '' +
testScript
