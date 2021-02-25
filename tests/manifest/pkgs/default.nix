{pkgs, system}:

rec {
  testService1 = import ./testService1.nix {
    inherit (pkgs) stdenv;
  };

  testService2 = import ./testService2.nix {
    inherit (pkgs) stdenv lib;
  };

  testService3 = import ./testService3.nix {
    inherit (pkgs) stdenv lib;
  };
}
