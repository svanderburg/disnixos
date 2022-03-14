{network, testScript, manifestFile, disnix, daemon, socat, libxml2, concatMapStrings, dysnomiaStateDir ? "/tmp/shared/dysnomia", postActivateTimeout ? 1}:

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
  ${targetName}.succeed(
      "${daemon}/bin/daemon --unsafe --pidfile /run/socat-backdoor.pid -- ${socat}/bin/socat tcp-listen:512,fork exec:/bin/sh"
  )
  ${targetName}.wait_for_file("/run/socat-backdoor.pid")
  ${targetName}.succeed("mkdir -p /var/state/dysnomia")
  ${targetName}.succeed(
      'if [ -d "${dysnomiaStateDir}/snapshots" ]; then ln -s ${dysnomiaStateDir}/snapshots /var/state/dysnomia/snapshots; fi'
  )
  ${targetName}.succeed(
      'if [ -d "${dysnomiaStateDir}/generations" ]; then ln -s ${dysnomiaStateDir}/generations /var/state/dysnomia/generations; fi'
  )

  # Create profile symlink

  profile = ${targetName}.succeed(
      "${libxml2}/bin/xmllint --xpath \"/manifest/profiles/profile[@name='${targetName}']/text()\" ${manifestFile}"
  )
  ${targetName}.succeed("mkdir -p /nix/var/nix/profiles/disnix")
  ${targetName}.succeed("ln -s {} /nix/var/nix/profiles/default".format(profile[:-1]))
'') (builtins.attrNames network) +
''

  ${firstTargetName}.succeed(
      "${disnix}/bin/disnix-activate --no-upgrade ${manifestFile}"
  )
  ${firstTargetName}.succeed("sleep ${toString postActivateTimeout}")
  ${firstTargetName}.succeed(
      "${disnix}/bin/disnix-restore --no-upgrade ${manifestFile}"
  )

  # fmt: on
  '' +
testScript
