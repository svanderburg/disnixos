{ networkFiles
, targetProperty
, clientInterface
, nixpkgs ? <nixpkgs>
, enableDisnix ? true
, nixOpsModel ? false
, disnix
, dysnomia
, nixops ? null
}:

let
  pkgs = import nixpkgs {};

  lib = import ./lib.nix { inherit nixpkgs pkgs; };

  generateDistributedDerivation = import ./generate-distributed-derivation.nix {
    inherit nixpkgs pkgs;
  };

  mergedNetwork = lib.generateMergedNetwork {
    inherit networkFiles nixOpsModel;
  };

  distributedDerivation = generateDistributedDerivation {
    network = mergedNetwork;
    inherit targetProperty clientInterface enableDisnix nixOpsModel dysnomia nixops;
    useVMTesting = false;
    useBackdoor = false;
  };

  generateDistributedDerivationXSL = "${disnix}/share/disnix/generatedistributedderivation.xsl";
in
pkgs.stdenv.mkDerivation {
  name = "distributedDerivation.xml";
  buildInputs = [ pkgs.libxslt ];
  distributedDerivationXML = builtins.toXML distributedDerivation;
  passAsFile = [ "distributedDerivationXML" ];

  buildCommand = ''
    if [ "$distributedDerivationXMLPath" != "" ]
    then
        xsltproc ${generateDistributedDerivationXSL} $distributedDerivationXMLPath > $out
    else
    (
    cat <<EOF
    $distributedDerivationXML
    EOF
    ) | xsltproc ${generateDistributedDerivationXSL} - > $out
    fi
  '';
}
