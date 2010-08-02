# This module allows the test driver to connect to the virtual machine
# via a root shell attached to port 514.

{ config, pkgs, ... }:

with pkgs.lib;

let

  # Urgh, `socat' sets the SIGCHLD to ignore.  This wreaks havoc with
  # some programs.
  rootShell = pkgs.writeScript "shell.pl"
    ''
      #! ${pkgs.perl}/bin/perl
      $SIG{CHLD} = 'DEFAULT';
      exec "/bin/sh";
    '';
in
    
{

  config = {

    jobs.backdoor =
      { startOn = "started network-interfaces";
        
        preStart =
          ''
            echo "guest running" > /dev/ttyS0
            echo "===UP===" > dev/ttyS0
          '';
          
        script =
          ''
            export USER=root
            export HOME=/root
            export DISPLAY=:0.0
            export GCOV_PREFIX=/tmp/coverage-data
            source /etc/profile
            cd /tmp
            exec ${pkgs.socat}/bin/socat tcp-listen:514,fork exec:${rootShell} 2> /dev/ttyS0
          '';
      };
  };
}

