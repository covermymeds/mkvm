 `mkvm.rb` is an easy-to-use command line mechanism to build VMware guests via VMware clone. The goal is to be simple to use for common tasks, but allow for customization as needed. Custom functionality can be provided through plugins.

Sane default values are provided for all optional arguments. All defaults can be overridden through the use of command line switches.

* [Installation](#installation)
* [Usage](#usage)
* [User Defaults](#user-defaults)
* [Templates](#templates)
* [PLugins](#plugins)
* [Examples](#examples)
* [License](#license)

## Installation

`mkvm.rb` requires the [RbVmomi](https://github.com/vmware/rbvmomi) library from VMware. Specifically, it requires version 1.8.2. You can install this with the `gem` command:

``` shell
$ sudo gem install rbvmomi --version 1.8.2
```

**Note**: support for building RHEL 7 systems requires vSphere API version 5.5 or higher.

## Usage

``` shell
Usage: mkvm.rb [options] hostname

VM options:
    -i, --ip ADDRESS                 IP address
    -g, --gateway GATEWAY            Gateway address
    -m, --netmask NETMASK            Subnet mask ()
    -d, --dns DNS1{,DNS2,...}        DNS server(s) to use ()
        --domain DOMAIN              DNS domain to append to hostname ()
        --extra "ONE=1 TWO=2"        extra args to pass to VMWare's extraConfigs during clone
    -t, --template TEMPLATE          VM template: small, medium, large, xlarge
        --sourcevm VMNAME            Source VM to clone to the target VM name.
        --cpu CPUs                   Number of CPUs
        --memory RAM                 Size of memory for the VM.  Include units (4G)
        --sdb [10G{,/pub}]           Add /dev/sdb. Size and mount point optional.
        --[no-]vm                    Build the VM (true)
VSphere options:
    -u, --user USER                  vSphere user name ($USER)
    -p, --password PASSWORD          vSphere password
    -H, --host HOSTNAME              vSphere host ()
    -D, --dc DATACENTER              vSphere data center ()
    -C, --cluster CLUSTER            vSphere cluster ()
        --clusterregex CLUSTER_REGEX vSphere cluster regex to use ()
        --[no-]insecure              Do not validate vSphere SSL certificate (true)
        --datastore DATASTORE        vSphere datastore to use ()
        --dsregex DATASTORE_REGEX    vSphere datastore regex to use ()
        --virthost                   Enable nested virtualization
automated IPAM options:
    -s, --subnet SUBNET              subnet in dotted quad with subnet mask, ex: 10.10.2.0/22
        --auto-uri uri               URI full path for auto IP system ex: http://blah/api/blah.php()
General options:
    -v, --debug                      Enable verbose output
    -h, --help                       This help message
```

The only mandatory arguments are `-t` (or `--custom` ) and a hostname with no plugins installed. The plugins provided in this repo will enforce additional mandatory arguments.

If no `-i` flag is supplied, `mkvm.rb` will, by default, perform a DNS lookup for the supplied hostname and use the results. If no `-i` flag is supplied and the DNS lookup fails, `mkvm.rb` will fail.

Most of the arguments should be self-explanatory, but a few merit discussion.

* **--cluster**: this is the vsphere compute cluster to use when building the VM. Either this option or --clusterregex must be supplied. If both parameters are supplied --cluster is used.
* **--clusterregex**: this is a regular expression that `mkvm.rb` will use to find the compute clusteer to use when building the VM. `mkvm.rb` will use this regex to determine the matching cluster name. Either this option or the explicit --cluster must be supplied.
* **--datastore**: this is the datastore to use when building the VM. Either this option or --dsregex must be supplied. If both parameters are supplied --datastore is used.
* **--dsregex**: this is a regular expression that `mkvm.rb` will use to find the datastore to use when building the VM. `mkvm.rb` will use this regex to enumerate all the matching datastores and then select the one with the most space free. This should help ensure that `mkvm.rb` doesn't over-populate any single datastore (unless, of course, you only have a single datastore!). This also allows you to control, on the fly, which datastore to use. Either this option or the explicit --datastore must be supplied.
* **--vlan**: this is the full name of the VLAN to which the VM will be assigned. This option is commented out as vlan does not apply to DV Switching. If you don't use DV Switching then you may want to uncomment this code.
* **--gateway**: this is the default route to use for this VM. It will be used for the Kickstart process, as well as for the resultant VM once built. If not specified, it defaults to the .1 address in the same network as the IP of the VM. Thus, if the VM IP is 192.168.1.5 and no gateway is specified, `mkvm.rb` will use 192.168.1.1.
* **--sdb [size{, path}]**: with no additional arguments, `sdb` adds a 10G /dev/sdb disk to the VM. Additionally, the value `SDB` is added to the Kickstart boot line. You may specify a size for your /dev/sdb disk. You may also specify a mount point for this disk. If you do so, the resultant Kickstart boot line will look like `SDB=/your/path` . Note that `mkvm.rb` **does not** actually mount this for you. It is your responsibility to handle this in your Kickstart file.
* **--app-env**: this is a value that gets added to the Kickstart command line. Your Kickstart process can parse this option and act accordingly. We use this to define a custom Puppet fact for whether the server is production, testing, development, etc.
* **--app-id**: this is an optional value that, if present, gets added to the Kickstart command line. Your Kickstart process can parse this option and act accordingly. We use this to define a custom Puppet fact that our applications can act upon.
* **--extra**: this is a free-form text argument that will be appended verbatim to your Kickstart boot line. Note that you must surround multiple elements with quotes in order to ensure that `mkvm.rb` sees these as an atomic unit.

Arguments that accept sizes can pass human-friendly suffixes:

* K = Kebibytes
* M = Mebibytes
* G = Gibibytes
* T = Tebibytes

## User Defaults

If a file `.mkvm.yaml` exists in the user's home directory, it will be loaded and the values found therein will be used for defaults. These defauls can still be overridden by command-line switches. The `:dvswitch` and `:portgroup` structures must be defined here.

``` yaml
:host: vcenter.example.com
:dc: primary
:cluster_regex: production
:username: administrator
:ds_regex: encrypted
:gateway: 192.168.1.1
:netmask: 255.255.255.0
:dns: 192.168.1.2,192.168.1.3
:domain: example.com
:app_env: development
:dvswitch:
  'dc1': 'dvswitch1uuid'
  'dc2': 'dvswitch2uuid'
:portgroup':
  '192.168.20.0':
    name: 'Production'
    portgroup: 'dvportgroup1-number'
  '192.168.30.0':
    name: 'DMZ'
    portgroup: 'dvportgroup2-number'
```

See `mkvm.yaml.sample` for a full example.

## Templates

mkvm knows about four pre-defined VM sizes:

| name | vCPU | Memory |
| :----: | :----: | :--------: |
| small | 1 | 1G |
| medium | 2 | 2G |
| large | 2 | 4G |
| xlarge | 2 | 8G |

## Plugins

`mkbm.rb` will look in the `plugins` directory for all files with an `.rb` extension. Any such files will be loaded. This allows users to extend the functionality of `mkvm.rb` on their own.

All plugins should extend the `Plugin` class, defined in `lib/plugin.rb` . Each plugin has numerous opportunities to interact with the overall process.

Plugins are run in alphabetical order from the `plugins` directory.

Plugins are **not** instantiated.

Several defaul plugins are provided:

* ip_pre_validate.rb: if no gateway address is provided, assume the user wants the .1 address of the network on which the VM is being created
* ip_post_validate.rb: perform a variety of santify checks to ensure the IP information is sane.

An example plugin is also provided (but not activated) to demonstrate how to add custom command line options.

## Examples

To create a small VM named bar:

``` shell
$ ./mkvm.rb -t small --sourcevm foo bar
```

This assumes that a fully-qualified domain name for foobar is already defined in DNS.

To create a small VM named bar with a specific IP address:

``` shell
$ ./mkvm.rb -t small -i 192.168.100.5 --sourcevm foo bar
```

To create a custom VM named bar with 3 vCPUs and 3 GB RAM, a specific IP address, and include a 100GB /dev/sdb disk:

``` bash
$ ./mkvm.rb --cpu 3 --memory 3G -i 192.168.100.5 --sdb 100G --sourcevm foo bar
```

## License

mkvm.rb is copyright 2014, CoverMyMeds, LLC and is released under the terms of the [GNU General Public License, version 2](http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt).

