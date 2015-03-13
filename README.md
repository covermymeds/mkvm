`mkvm.rb` is an easy-to-use command line mechanism to build VMware guests.  The goal is to be simple to use for common tasks, but allow for customization as needed. Custom functionality can be provided through plugins.

Sane default values are provided for all optional arguments. All defaults can be overridden through the use of command line switches.

* [Installation](#installation)
* [Usage](#usage)
* [User Defaults](#user-defaults)
* [Templates](#templates)
* [PLugins](#plugins)
* [Examples](#examples)
* [License](#license)

## Installation
`mkvm.rb` requires the [RbVmomi](https://github.com/vmware/rbvmomi) library from VMware.  Specifically, it requires version 1.6.0.  You can install this with the `gem` command:

```shell
$ sudo gem install rbvmomi --version 1.6.0
```

You'll also need the `mkisofs` binary in your path.  Linux users can install the appropriate package (genisoimage for RHEL).  Mac users can install the cdrtools package from Homebrew:
```shell
$ sudo brew install cdrtools
```

Finally, you'll need a copy of the [isolinux](http://www.syslinux.org/wiki/index.php/ISOLINUX) directory used for creating ISO images (assuming you actually want to create them). The necessary files are included in the `isolinux` directory of this repository. You can also copy the `isolinux` directory from your Linux vendor's installation disc (or disc image). In that case, be sure to copy the `isolinux.cfg` file from this repository into your `isolinux` directory, and adjust as needed.

## Usage
```shell
Usage: mkvm.rb [options] hostname

Kickstart options:
    -r, --major VERSION              Major OS release to use (6)
        --url URL                    Kickstart URL
    -k, --ksdevice TYPE              ksdevice type to use (eth0)
    -i, --ip ADDRESS                 IP address
    -g, --gateway GATEWAY            Gateway address
    -m, --netmask NETMASK            Subnet mask (255.255.255.0)
    -d, --dns DNS1{,DNS2,...}        DNS server(s) to use
        --domain DOMAIN              DNS domain to append to hostname
        --app-env APP_ENV            APP_ENV (development)
        --app-id APP_ID              APP_ID
        --extra "ONE=1 TWO=2"        extra args to pass to boot line
ISO options:
        --srcdir DIR                 Directory containing isolinux templates (./isolinux)
        --outdir DIR                 Directory in which to write the ISO (./iso)
VSphere options:
    -u, --user USER                  vSphere user name
    -p, --password PASSWORD          vSphere password
    -H, --host HOSTNAME              vSphere host
    -D, --dc DATACENTER              vSphere data center
    -C, --cluster CLUSTER            vSphere cluster
        --[no-]insecure              Do not validate vSphere SSL certificate (true)
        --datastore DATASTORE        vSphere datastore regex to use
        --isostore ISOSTORE          vSphere ISO store to use
VM options:
    -t, --template TEMPLATE          VM template: small, medium, large, xlarge
        --custom cpu,mem,sda         CPU, Memory, and /dev/sda
        --sdb [10G{,/pub}]           Add /dev/sdb. Size and mount point optional.
        --vlan VLAN                  VLAN (This option is deprecated, but code left in place commented out if you need it)
        --[no-]iso                   Build ISO (true)
        --[no-]upload                Upload the ISO to the ESX cluster (true)
        --[no-]vm                    Build the VM (true)
        --[no-]power                 Power on the VM after building it (true)
General options:
    -v, --debug                      Verbose output
    -h, --help                       Display this screen
```
The only mandatory arguments are `-t` (or `--custom`) and a hostname with no plugins installed.  The plugins provided in this repo will enforce additional mandatory arguments. 

If no `-i` flag is supplied, `mkvm.rb` will, by default, perform a DNS lookup for the supplied hostname and use the results.  If no `-i` flag is supplied and the DNS lookup fails, `mkvm.rb` will fail.

The `srcdir` parameter is expected to be a directory that contains sub-directories that match the major version of the system being built.  That is, if you're building a RHEL 7 system, your `srcdir` directory should have a sub-directory named `7` that contains the isolinux files for that release.

```shell
$ tree -d isolinux/
isolinux/
├── 6
├── 7
└── tmp

3 directories
```

The default value of `srcdir` is the isolinux directory in this repo, which contains the sub-directories and templates expected.

The `outdir` parameter is where you want ISOs to be stored. This defaults to the `iso` directory in this repo.

Most of the arguments should be self-explanatory, but a few merit discussion.

* **--datastore**: this is a regular expression that `mkvm.rb` will use to find the datastore to use when building the VM. `mkvm.rb` will use this regex to enumerate all the matching datastores and then select the one with the most space free. This should help ensure that `mkvm.rb` doesn't over-populate any single datastore (unless, of course, you only have a single datastore!).  This also allows you to control, on the fly, which datastore to use.
* **--isostore**: this is the datastore to which the resultant ISO file will be pushed. This store should be accessible by all the hosts within the cluster, to ensure that any host can build the VM.  A low-performance NFS share is usually suitable for this purpose.
* **--vlan**: this is the full name of the VLAN to which the VM will be assigned. This option is commented out as vlan does not apply to DV Switching.  If you don't use DV Switching then you may want to uncomment this code.
* **--gateway**: this is the default route to use for this VM.  It will be used for the Kickstart process, as well as for the resultant VM once built.  If not specified, it defaults to the .1 address in the same network as the IP of the VM.  Thus, if the VM IP is 192.168.1.5 and no gateway is specified, `mkvm.rb` will use 192.168.1.1.
* **--sdb [size{,path}]**: with no additional arguments, `sdb` adds a 10G /dev/sdb disk to the VM.  Additionally, the value `SDB` is added to the Kickstart boot line.  You may specify a size for your /dev/sdb disk.  You may also specify a mount point for this disk.  If you do so, the resultant Kickstart boot line will look like `SDB=/your/path`.  Note that `mkvm.rb` **does not** actually mount this for you.  It is your responsibility to handle this in your Kickstart file.
* **--app-env**: this is a value that gets added to the Kickstart command line. Your Kickstart process can parse this option and act accordingly. We use this to define a custom Puppet fact for whether the server is production, testing, development, etc.
* **--app-id**: this is an optional value that, if present, gets added to the Kickstart command line. Your Kickstart process can parse this option and act accordingly. We use this to define a custom Puppet fact that our applications can act upon.
* **--extra**: this is a free-form text argument that will be appended verbatim to your Kickstart boot line.  Note that you must surround multiple elements with quotes in order to ensure that `mkvm.rb` sees these as an atomic unit.

Arguments that accept sizes can pass human-friendly suffixes:
* K = Kebibytes
* M = Mebibytes
* G = Gibibytes
* T = Tebibytes

## User Defaults
If a file `.mkvm.yaml` exists in the user's home directory, it will be loaded and the values found therein will be used for defaults. These defauls can still be overridden by command-line switches. The `:dvswitch` and `:portgroup` structures must be defined here.

```yaml
:host: vcenter.example.com
:dc: primary
:cluster: production
:username: administrator
:ds_regex: encrypted
:iso_store: ESX_ISO
:url: https://ks.example.com/rhel6.ks
:gateway: 192.168.1.1
:netmask: 255.255.255.0
:dns: 192.168.1.2,192.168.1.3
:domain: example.com
:app_env: development
:srcdir: /nfs/isolinux
:outdir: /nfs/isos
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

| name | vCPU | Memory | /dev/sda |
| :----: | :----: | :------: | :--------: |
| small | 1 | 1G | 15GB |
| medium | 2 | 2G | 15GB |
| large | 2 | 4G | 15GB |
| xlarge | 2 | 8G | 15GB |

## Plugins
`mkbm.rb` will look in the `plugins` directory for all files with an `.rb` extension.  Any such files will be loaded.  This allows users to extend the functionality of `mkvm.rb` on their own.

All plugins should extend the `Plugin` class, defined in `lib/plugin.rb`.  Each plugin has numerous opportunities to interact with the overall process.

Plugins are **not** instantiated.

Several defaul plugins are provided:
* ip_pre_validate.rb: if no gateway address is provided, assume the user wants the .1 address of the network on which the VM is being created
* ip_post_validate.rb: perform a variety of santify checks to ensure the IP information is sane.

An example plugin is also provided (but not activated) to demonstrate how to add custom command line options.

## Examples
To create a small VM named foobar:
```shell
$ ./mkvm.rb -t small foobar
```
This assumes that a fully-qualified domain name for foobar is already defined in DNS.

To create a small VM named foobar with a specific IP address:
```shell
$ ./mkvm.rb -t small -i 192.168.100.5 foobar
```

To create a custom VM named foobar with 3 vCPUs, 3 GB RAM, a 30 GB /dev/sda, a specific IP address, and include a 100GB /dev/sdb disk:
```bash
$ ./mkvm.rb --custom 3,3G,30G -i 192.168.100.5 --sdb 100G foobar
```

Create an ISO for a medium RHEL 7 system named foobar and pass a couple of extra options to the boot command line:
```bash
$ ./mkvm.rb -t medium -r 7 --extra "console=ttyS0 ks.sendmac noverifyssl sshd" foobar
```

## License
mkvm.rb is copyright 2014, CoverMyMeds, LLC and is released under the terms of the [GNU General Public License, version 2](http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt).
