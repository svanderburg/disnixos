{network, testScript, manifestFile, disnix, socat, concatMapStrings, dysnomiaStateDir ? "/tmp/shared/dysnomia"}:

''
  startAll;
  my $pid;
  
  ${concatMapStrings (targetName:
    ''
      ${"\$"}${targetName}->waitForJob("network.target");
      ${"\$"}${targetName}->waitForJob("disnix.service");
      ${"\$"}${targetName}->mustSucceed("iptables -I INPUT -p tcp --dport 512 -j ACCEPT || true");
      $pid = ${"\$"}${targetName}->mustSucceed("${socat}/bin/socat tcp-listen:512,fork exec:/bin/sh & echo -n \$!");
      ${"\$"}${targetName}->mustSucceed("while [ \"\$(ps -p $pid | grep socat)\" = \"\" ]; do sleep 0.5; done");
      ${"\$"}${targetName}->mustSucceed("mkdir -p /var/state/dysnomia");
      ${"\$"}${targetName}->mustSucceed("if [ -d \"${dysnomiaStateDir}/snapshots\" ]; then ln -s ${dysnomiaStateDir}/snapshots /var/state/dysnomia/snapshots; fi");
      ${"\$"}${targetName}->mustSucceed("if [ -d \"${dysnomiaStateDir}/generations\" ]; then ln -s ${dysnomiaStateDir}/generations /var/state/dysnomia/generations; fi");
    '') (builtins.attrNames network)}
    
    ${"\$"}${builtins.head (builtins.attrNames network)}->mustSucceed("${disnix}/bin/disnix-activate --no-upgrade ${manifestFile}");
    ${"\$"}${builtins.head (builtins.attrNames network)}->mustSucceed("${disnix}/bin/disnix-restore --no-upgrade ${manifestFile}");
    
    ${testScript}
''
