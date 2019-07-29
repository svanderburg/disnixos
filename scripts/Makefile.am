disnix-backdoor-client.1: disnix-backdoor-client.in
	$(HELP2MAN) --output=$@ --no-info --name 'Provides access to the disnix-service through a socket with public access' "$(SHELL) disnix-backdoor-client"

disnix-backdoor-client.1.xml: disnix-backdoor-client.1
	$(SHELL) ../maintenance/man2docbook.bash $<

disnix-nixops-client.1: disnix-nixops-client.in
	$(HELP2MAN) --output=$@ --no-info --name 'Provides access to the disnix-service through NixOps SSH interface' "$(SHELL) disnix-nixops-client"

disnix-nixops-client.1.xml: disnix-nixops-client.1
	$(SHELL) ../maintenance/man2docbook.bash $<

disnixos-geninfra.1: disnixos-geninfra.in
	$(HELP2MAN) --output=$@ --no-info --name 'Generate an infrastructure model from network models' "$(SHELL) disnixos-geninfra"

disnixos-geninfra.1.xml: disnixos-geninfra.1
	$(SHELL) ../maintenance/man2docbook.bash $<

disnixos-gentests.1: disnixos-gentests.in
	$(HELP2MAN) --output=$@ --no-info --name 'Generate initalialization steps of the test suite' "$(SHELL) disnixos-gentests"

disnixos-gentests.1.xml: disnixos-gentests.1
	$(SHELL) ../maintenance/man2docbook.bash $<

disnixos-instantiate.1: disnixos-instantiate.in
	$(HELP2MAN) --output=$@ --no-info --name 'Instantiate a distributed derivation from DisnixOS expressions' "$(SHELL) disnixos-instantiate"

disnixos-instantiate.1.xml: disnixos-instantiate.1
	$(SHELL) ../maintenance/man2docbook.bash $<

disnixos-manifest.1: disnixos-manifest.in
	$(HELP2MAN) --output=$@ --no-info --name 'Generate a manifest file from DisnixOS expressions' "$(SHELL) disnixos-manifest"

disnixos-manifest.1.xml: disnixos-manifest.1
	$(SHELL) ../maintenance/man2docbook.bash $<

disnixos-delegate.1: disnixos-delegate.in
	$(HELP2MAN) --output=$@ --no-info --name 'Delegates service and infrastructure builds to the target machines' "$(SHELL) disnixos-delegate"

disnixos-delegate.1.xml: disnixos-delegate.1
	$(SHELL) ../maintenance/man2docbook.bash $<

disnixos-env.1: disnixos-env.in
	$(HELP2MAN) --output=$@ --no-info --name 'Installs or updates the services and infrastructure of a distributed system' "$(SHELL) disnixos-env"

disnixos-env.1.xml: disnixos-env.1
	$(SHELL) ../maintenance/man2docbook.bash $<

disnixos-deploy-network.1: disnixos-deploy-network.in
	$(HELP2MAN) --output=$@ --no-info --name 'Installs or updates the infrastructure of a distributed system' "$(SHELL) disnixos-deploy-network"

disnixos-deploy-network.1.xml: disnixos-deploy-network.1
	$(SHELL) ../maintenance/man2docbook.bash $<

disnixos-snapshot-network.1: disnixos-snapshot-network.in
	$(HELP2MAN) --output=$@ --no-info --name 'Snapshots the state of all mutable components belonging to the system configurations' "$(SHELL) disnixos-snapshot-network"

disnixos-snapshot-network.1.xml: disnixos-snapshot-network.1
	$(SHELL) ../maintenance/man2docbook.bash $<

disnixos-restore-network.1: disnixos-restore-network.in
	$(HELP2MAN) --output=$@ --no-info --name 'Restores the state of all mutable components belonging to the system configurations' "$(SHELL) disnixos-restore-network"

disnixos-restore-network.1.xml: disnixos-restore-network.1
	$(SHELL) ../maintenance/man2docbook.bash $<

disnixos-collect-garbage.1: disnixos-collect-garbage.in
	$(HELP2MAN) --output=$@ --no-info --name 'Delete garbage from a network of machines' "$(SHELL) disnixos-collect-garbage"

disnixos-collect-garbage.1.xml: disnixos-collect-garbage.1
	$(SHELL) ../maintenance/man2docbook.bash $<

disnixos-clean-snapshots.1: disnixos-clean-snapshots.in
	$(HELP2MAN) --output=$@ --no-info --name 'Delete older generation of snapshots from a network of machines' "$(SHELL) disnixos-clean-snapshots"

disnixos-clean-snapshots.1.xml: disnixos-clean-snapshots.1
	$(SHELL) ../maintenance/man2docbook.bash $<

disnixos-delete-network-state.1: disnixos-delete-network-state.in
	$(HELP2MAN) --output=$@ --no-info --name 'Deletes the obsolete state of mutable components that have been undeployed' "$(SHELL) disnixos-delete-network-state"

disnixos-delete-network-state.1.xml: disnixos-delete-network-state.1
	$(SHELL) ../maintenance/man2docbook.bash $<

disnixos-query.1: disnixos-query.in
	$(HELP2MAN) --output=$@ --no-info --name 'Query the installed services from machines' "$(SHELL) disnixos-query"

disnixos-query.1.xml: disnixos-query.1
	$(SHELL) ../maintenance/man2docbook.bash $<

disnixos-vm-env.1: disnixos-vm-env.in
	$(HELP2MAN) --output=$@ --no-info --name 'Deploys and runs a distributed system in a network of VMs spawned by the NixOS test driver' "$(SHELL) disnixos-vm-env"

disnixos-vm-env.1.xml: disnixos-vm-env.1
	$(SHELL) ../maintenance/man2docbook.bash $<

disnixos-capture-manifest.1: disnixos-capture-manifest.in
	$(HELP2MAN) --output=$@ --no-info --name 'Captures all the ingredients for reconstructing a deployment manifest from the manifests of the target profiles' --libtool "$(SHELL) disnixos-capture-manifest"

disnixos-capture-manifest.1.xml: disnixos-capture-manifest.1
	$(SHELL) ../maintenance/man2docbook.bash $<

disnixos-reconstruct.1: disnixos-reconstruct.in
	$(HELP2MAN) --output=$@ --no-info --name 'Reconstructs the deployment manifest on the coordinator machine from the manifests on the target machines' --libtool "$(SHELL) disnixos-reconstruct"

disnixos-reconstruct.1.xml: disnixos-reconstruct.1
	$(SHELL) ../maintenance/man2docbook.bash $<

disnixos-convert-manifest.1: disnixos-convert-manifest.in
	$(HELP2MAN) --output=$@ --no-info --name 'Converts a manifest file using the old V1 schema into V2 format' --libtool "$(SHELL) disnixos-convert-manifest"

disnixos-convert-manifest.1.xml: disnixos-convert-manifest.1
	$(SHELL) ../maintenance/man2docbook.bash $<

disnixos-convert.1: disnixos-convert.in
	$(HELP2MAN) --output=$@ --no-info --name 'Converts a deployment using V1 manifests to V2' --libtool "$(SHELL) disnixos-convert"

disnixos-convert.1.xml: disnixos-convert.1
	$(SHELL) ../maintenance/man2docbook.bash $<

bin_SCRIPTS = disnix-backdoor-client disnix-nixops-client disnixos-geninfra \
  disnixos-gentests disnixos-instantiate disnixos-manifest disnixos-delegate \
  disnixos-env disnixos-vm-env disnixos-deploy-network disnixos-collect-garbage \
  disnixos-clean-snapshots disnixos-query disnixos-snapshot-network \
  disnixos-restore-network disnixos-delete-network-state \
  disnixos-capture-manifest disnixos-reconstruct disnixos-convert-manifest \
  disnixos-convert
pkgdata_SCRIPTS = checks
noinst_DATA = disnix-backdoor-client.1.xml disnix-nixops-client.1.xml \
  disnixos-geninfra.1.xml disnixos-gentests.1.xml disnixos-instantiate.1.xml \
  disnixos-manifest.1.xml disnixos-delegate.1.xml disnixos-env.1.xml \
  disnixos-deploy-network.1.xml disnixos-collect-garbage.1.xml \
  disnixos-clean-snapshots.1.xml disnixos-query.1.xml disnixos-vm-env.1.xml \
  disnixos-capture-manifest.1.xml disnixos-reconstruct.1.xml \
  disnixos-delete-network-state.1.xml disnixos-snapshot-network.1.xml \
  disnixos-restore-network.1.xml disnixos-convert-manifest.1.xml \
  disnixos-convert.1.xml
man1_MANS = disnix-backdoor-client.1 disnix-nixops-client.1 disnixos-geninfra.1 \
  disnixos-gentests.1 disnixos-instantiate.1 disnixos-manifest.1 \
  disnixos-delegate.1 disnixos-env.1 disnixos-deploy-network.1 \
  disnixos-collect-garbage.1 disnixos-clean-snapshots.1 disnixos-query.1 \
  disnixos-vm-env.1 disnixos-snapshot-network.1 disnixos-restore-network.1 \
  disnixos-delete-network-state.1 disnixos-capture-manifest.1 \
  disnixos-reconstruct.1 disnixos-convert-manifest.1 disnixos-convert.1

EXTRA_DIST = disnix-backdoor-client.in disnix-nixops-client.in \
  disnixos-geninfra.in disnixos-gentests.in disnixos-instantiate.in \
  disnixos-manifest.in disnixos-delegate.in disnixos-env.in disnixos-vm-env.in \
  disnixos-deploy-network.in disnixos-collect-garbage.in \
  disnixos-clean-snapshots.in disnixos-query.in disnixos-convert-manifest.in \
  disnixos-convert.in \
  $(pkgdata_SCRIPTS) \
  $(man1_MANS) \
  $(noinst_DATA)
