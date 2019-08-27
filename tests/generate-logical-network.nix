{writeTextFile}:

writeTextFile {
  name = "network-logical.nix";

  text = ''
    {
      testtarget1 = {pkgs, ...}:

      {
        environment.systemPackages = [ pkgs.zip ];
      };

      testtarget2 = {pkgs, ...}:

      {
        environment.systemPackages = [ pkgs.hello ];
      };
    }
  '';
}
