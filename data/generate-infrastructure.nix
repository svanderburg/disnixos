{networkFile}:

let
  inherit (builtins) getAttr attrNames readFile;
  
  pkgs = import (builtins.getEnv "NIXPKGS_ALL") {};
  network = import networkFile;
  
  infrastructureString =
    "{\n"+    
    (pkgs.lib.concatMapStrings (targetName:
      let
        configuration = getAttr targetName network;
        config = (import /etc/nixos/nixos/lib/eval-config.nix { modules = [ configuration ]; }).config;
      in
        "  "+targetName+" = {\n"+
        "    backdoor = \"@port@.socket\";\n"+
	"    hostname = \"${targetName}\";\n"+
	"    system = \"i686-linux\";"
      +
        (if config.services.tomcat.enable then
          "    tomcatPort = 8080;\n"
        else "")
      +
        (if config.services.mysql.enable then	  
	  "    mysqlUsername = \"root\";\n"+
	  "    mysqlPassword = \"${readFile config.services.mysql.rootPassword}\";\n"+
          "    mysqlPort = 3306;\n"
        else "")
      +
      "  };\n\n"
      
    ) (attrNames network)) +
    "}\n";
in
pkgs.stdenv.mkDerivation {
  name = "infrastructure.nix";
  buildCommand = ''
cat > $out <<EOF
${infrastructureString}
EOF
    
port=65280
    
while [ "$(grep "@port@" $out)" != "" ]
do
    port2=$((port++))
    sed -i -e "0,/@port@/s//$port2/" $out
done
'';
}
