{ nixpkgs, nixos, system }:

let pkgs = import nixpkgs { config = {}; inherit system; }; in

with pkgs;
with import "${nixos}/lib/qemu-flags.nix";

rec {

  inherit pkgs;
  
  # Build a virtual network from an attribute set `{ machine1 =
  # config1; ... machineN = configN; }', where `machineX' is the
  # hostname and `configX' is a NixOS system configuration. 
  #
  # forwardPorts is a list of attribute sets 
  # `[ { hostPort = hostPortN; guestPort = guestPortN; } ...  ]` to enable
  # fowarding of a host TCP port to a guest TCP port.
  #
  # The result is a script that starts a QEMU instance for each virtual
  # machine.  Each machine is given an arbitrary IP address in the
  # virtual network.
  
  buildVirtualNetwork =
    { nodes, forwardPorts ? [] }:

    let nodes_ = lib.mapAttrs (n: buildVM nodes_) (assignIPAddresses nodes); in

    stdenv.mkDerivation {
      name = "vms";
      buildCommand =
        ''
          ensureDir $out/vms
          ${
            lib.concatMapStrings (vm:
              ''
                ln -sn ${vm.config.system.build.vm} $out/vms/${vm.config.networking.hostName}
              ''
            ) (lib.attrValues nodes_)
          }

          ensureDir $out/bin
          cat > $out/bin/run-vms <<EOF
          #! ${stdenv.shell}
 
          ${
            lib.concatMapStrings (mapping:
            ''
              port=${toString mapping.hostPort}
              count=0

              for i in $out/vms/*; do
                  port2=\$((port++))
                  count2=\$((count++))
                  echo "forwarding localhost:\$port2 to \$(basename \$i):${toString mapping.guestPort}"
                  QEMU_OPTS_ARRAY[\$count2]="\''${QEMU_OPTS_ARRAY[\$count2]} -redir tcp:\$port2::${toString mapping.guestPort}"
              done                
            '') forwardPorts
          }

          count=0
          for i in $out/vms/*; do
              count2=\$((count++))
              QEMU_OPTS="\''${QEMU_OPTS_ARRAY[\$count2]}" \$i/bin/run-*-vm &
          done
          EOF
          chmod +x $out/bin/run-vms
        ''; # */
      passthru = { nodes = nodes_; };
    };


  buildVM =
    nodes: configurations:

    import "${nixos}/lib/eval-config.nix" {
      inherit nixpkgs system;
      services = null;
      modules = configurations ++
        [ ./qemu-vm.nix
	  ./backdoor.nix
          { key = "no-manual"; services.nixosManual.enable = false; }
        ];
      extraArgs = { inherit nodes; };
    };


  # Given an attribute set { machine1 = config1; ... machineN =
  # configN; }, sequentially assign IP addresses in the 192.168.1.0/24
  # range to each machine, and set the hostname to the attribute name.
  assignIPAddresses = nodes:

    let
    
      machines = lib.attrNames nodes;

      machinesNumbered = lib.zipTwoLists machines (lib.range 1 254);

      nodes_ = lib.flip map machinesNumbered (m: lib.nameValuePair m.first
        [ ( { config, pkgs, nodes, ... }:
            let
              interfacesNumbered = lib.zipTwoLists config.virtualisation.vlans (lib.range 1 255);
              interfaces = 
                lib.flip map interfacesNumbered ({ first, second }:
                  { name = "eth${toString second}";
                    ipAddress = "192.168.${toString first}.${toString m.second}";
                  }
                );
            in
            { key = "ip-address";
              config =
                { networking.hostName = m.first;
                
                  networking.interfaces = interfaces;
                    
                  networking.primaryIPAddress =
                    lib.optionalString (interfaces != []) (lib.head interfaces).ipAddress;
                  
                  # Put the IP addresses of all VMs in this machine's
                  # /etc/hosts file.  If a machine has multiple
                  # interfaces, use the IP address corresponding to
                  # the first interface (i.e. the first network in its
                  # virtualisation.vlans option).
                  networking.extraHosts = lib.flip lib.concatMapStrings machines
                    (m: let config = (lib.getAttr m nodes).config; in
                      lib.optionalString (config.networking.primaryIPAddress != "")
                        ("${config.networking.primaryIPAddress} " +
                         "${config.networking.hostName}\n"));
                  
                  virtualisation.qemu.options =
                    lib.flip lib.concatMapStrings interfacesNumbered
                      ({ first, second }: qemuNICFlags second first );
                };
            }
          )
          (lib.getAttr m.first nodes)
        ] );

    in lib.listToAttrs nodes_;
}
