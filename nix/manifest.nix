{ networkFiles
, targetProperty
, clientInterface
, nixpkgs ? <nixpkgs>
, enableDisnix ? true
, nixOpsModel ? false
, useVMTesting ? false
, useBackdoor ? false
, disnix
, dysnomia
, nixops ? null
}:

let
  pkgs = import nixpkgs {};

  lib = import ./lib.nix { inherit nixpkgs pkgs; };

  generateManifest = import ./generate-manifest.nix { inherit nixpkgs pkgs; };

  mergedNetwork = lib.generateMergedNetwork {
    inherit networkFiles nixOpsModel;
  };

  manifest = generateManifest {
    network = mergedNetwork;
    inherit targetProperty clientInterface enableDisnix nixOpsModel useVMTesting useBackdoor dysnomia nixops;
  };

  generateManifestXSL = "${disnix}/share/disnix/generatemanifest.xsl";
in
pkgs.stdenv.mkDerivation {
  name = "manifest.xml";
  buildInputs = [ pkgs.libxslt ];
  manifestXML = builtins.toXML manifest;
  passAsFile = [ "manifestXML" ];

  buildCommand = ''
    if [ "$manifestXMLPath" != "" ]
    then
        xsltproc ${generateManifestXSL} $manifestXMLPath > $out
    else
    (
    cat <<EOF
    $manifestXML
    EOF
    ) | xsltproc ${generateManifestXSL} - > $out
    fi
  '';
}
