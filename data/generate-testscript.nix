{network, testScript, manifestFile, disnix, socat, concatMapStrings}:

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
    '') (builtins.attrNames network)}
    
    ${"\$"}${builtins.head (builtins.attrNames network)}->mustSucceed("${disnix}/bin/disnix-activate --no-coordinator-profile --no-lock --no-upgrade ${manifestFile}");
    
    ${testScript}
''
