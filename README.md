DisnixOS
========
DisnixOS is a distributed infrastructure deployment extension for Disnix.
Disnix's responsibility is to deploy distributable components (i.e. services)
into a network of machines. However, the underlying system configurations of
these machines (the infrastructure) also need to be deployed and upgraded.

DisnixOS provides complementary infrastructure deployment using [NixOS](http://nixos.org/nixos),
a Linux distribution that allows entire system configurations to be deployed with
the Nix package manager from a single declarative specification.

Optionally, it can use [NixOps](http://github.com/nixos/nixops), a NixOS-based
cloud deployment tool to perform infrastructure deployment. NixOps supports
automatic instantiation and provision of VM instances.

Prerequisites
=============
In order to build Disnix from source code, the following packages are required:

* [Disnix](http://github.com/svanderburg/disnix)
* [NixOps](http://github.com/nixos/nixops), if it is desired to use NixOps' infrastructure deployment facilities

These dependencies can be acquired with the Nix package manager, your host
system's package manager or be compiled from sources. Consult the documentation
of your distribution or the corresponding packages for more information.

Installation
============
DisnixOS is a typical autotools based package which can be compiled and installed
by running the following commands in a shell session:

    $ ./configure
    $ make
    $ make install

For more information about using the autotools setup or for customizing the
configuration, take a look at the `./INSTALL` file.

Usage
=====
DisnixOS supports various deployment operations.

Deploying infrastructure
------------------------
In order to deploy infrastructure (i.e. a network of NixOS machines), one must
create on or more NixOS network models that define a network of NixOS
configurations.

By running the following command-line instruction with at least one network model
as a parameter, the system configuration will be deployed through Disnix:

    $ disnixos-deploy-network network.nix

Deploying services and infrastructure at the same time
------------------------------------------------------
Besides infrastructure only, we can also deploy services and infrastructure at
the same time. For example:

    $ disnixos-env -s services.nix -n network.nix -d distribution.nix

The above command-line instruction first deploys the infrastructure and then
the services using Disnix. The infrastructure model is generated automatically
from the NixOS network model.

Deploying services and infrastructure in a network of QEMU VMs
--------------------------------------------------------------
We can also spawn a network of efficiently instantiated QEMU VMs in which a
service-oriented system is deployed through Disnix:

    $ disnixos-vm-env -s services.nix -n network.nix -d distribution.nix
    
The above command uses NixOS' test driver to quickly set up VMs and is
paricularly useful to quickly test a deployment.

Deploying infrastructure through NixOps and services through Disnix
------------------------------------------------------------------
We can also use NixOps to deploy instantiate and deploy infrastructure, and use
Disnix to deploy the services to the corresponding VM instances.

The following command instantiates and deploys a network of VirtualBox machines:

    $ nixops create ./network.nix ./network-virtualbox.nix -d test
    $ nixops deploy -d test

The following environment variable specifies that we want to deploy in a network
called `test` that is deployed by NixOps:

    $ export NIXOPS_DEPLOYMENT=test

The following command deploys the services into the network deployed by NixOps:
    
    $ disnixos-env -s services.nix -n network.nix -n network-virtualbox.nix -d distribution.nix --use-nixops

Manual
======
DisnixOS has a nice Docbook manual that can be compiled yourself. However, it is
also available [online](http://hydra.nixos.org/job/disnix/disnixos-trunk/tarball/latest/download-by-type/doc/manual).

License
=======
DisnixOS is free software; you can redistribute it and/or modify it under the
terms of the [GNU Lesser General Public License](http://www.gnu.org/licenses/lgpl.html)
as published by the [Free Software Foundation](http://www.fsf.org) either version
2.1 of the License, or (at your option) any later version. Disnix is distributed
in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU Lesser General Public License for more details.
