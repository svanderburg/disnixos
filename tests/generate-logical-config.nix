{writeTextFile}:

writeTextFile {
  name = "network-logical.nix";
  text = ''
    {
      server = {pkgs, ...}:

      {
        environment.systemPackages = [ pkgs.zip ];

        environment.etc."dysnomia/properties" = {
          source = pkgs.writeTextFile {
            name = "dysnomia-properties";
            text = '''
              foo=bar
              supportedTypes=("process" "wrapper")
            ''';
          };
        };
      };
    }
  '';
}
