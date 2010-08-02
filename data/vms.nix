{networkFile}:

let nodes = import networkFile;
in
(import ./build-vms.nix { nixpkgs = /etc/nixos/nixpkgs; nixos = /etc/nixos/nixos; system = builtins.currentSystem; }).buildVirtualNetwork {
  inherit nodes;
  forwardPorts = [ { hostPort = 65280; guestPort = 514; } ];
}
