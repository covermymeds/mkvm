`mkvm.rb` is the cool new way to build VMware guests.  The goal is to be simple to use for common tasks, but allow for customization as needed.

Sane default values are provided for all optional arguments. All defaults can be overridden through the use of command line switches.

* [Installation](#installation)
* [Usage](#usage)
* [User Defaults](#user-defaults)
* [Templates](#templates)
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

    -u, --user USER                  vSphere user name ($USER)
    -p, --password PASSWORD          vSphere password
    -H, --host HOSTNAME              vSphere host
    -D, --dc DATACENTER              vSphere data center
    -C, --cluster CLUSTER            vSphere cluster
        --[no-]insecure              Do not validate vSphere SSL certificate (true)
        --datastore DATASTORE        vSphere datastore regex to use
        --isostore ISOSTORE          vSphere ISO store to use
    -i, --ip ADDRESS                 IP address
    -g, --gateway GATEWAY            Gateway address
    -m, --netmask NETMASK            Subnet mask
    -d, --dns DNS1{,DNS2,...}        Comma-separated list of DNS servers
    -e, --env APP_ENV                APP_ENV
    -a, --app APP_ID                 APP_ID
        --url URL                    Kickstart URL
        --dir DIR                    Directory containing isolinux template (.)
        --domain DOMAIN              DNS domain to append to hostname
    -t, --template TEMPLATE          VM template: tiny, small, medium, large, xlarge
        --custom cpu,mem,sda         CPU, Memory, and /dev/sda for VM
        --sdb [KB]                   Size of optional /dev/sdb in KB (10485760)
        --vlan VLAN                  VLAN name
        --[no-]iso                   Build ISO (true)
        --[no-]upload                Upload the ISO to the ESX cluster (true)
        --[no-]vm                    Build the VM (true)
        --[no-]power                 Power on the VM after building it (true)
    -v, --debug                      Verbose output
    -h, --help                       Display this screen
```
The only mandatory arguments are `-t` (or `--custom`) and a hostname. 

If no `-i` flag is supplied, `mkvm.rb` will perform a DNS lookup for the supplied hostname and use the results.  If no `-i` flag is supplied and the DNS lookup fails, `mkvm.rb` will fail.

Most of the arguments should be self-explanatory, but a few merit discussion.

* **--datastore**: this is a regular expression that `mkvm.rb` will use to find the datastore to use when building the VM. `mkvm.rb` will use this regex to enumerate all the matching datastores and then select the one with the most space free. This should help ensure that `mkvm.rb` doesn't over-populate any single datastore (unless, of course, you only have a single datastore!).  This also allows you to control, on the fly, which datastore to use.
* **--isostore**: this is the datastore to which the resultant ISO file will be pushed. This store should be accessible by all the hosts within the cluster, to ensure that any host can build the VM.  A low-performance NFS share is usually suitable for this purpose.
* **--gateway**: this is the default route to use for this VM.  It will be used for the Kickstart process, as well as for the resultant VM once built.  If not specified, it defaults to the .1 address in the same network as the IP of the VM.  Thus, if the VM IP is 192.168.1.5 and no gateway is specified, `mkvm.rb` will use 192.168.1.1.
* **--app-env**: this is a value that gets added to the Kickstart command line. Your Kickstart process can parse this option and act accordingly. We use this to define a custom Puppet fact for whether the server is production, testing, development, etc.
* **--app-id**: this is an optional value that, if present, gets added to the Kickstart command line. Your Kickstart process can parse this option and act accordingly. We use this to define a custom Puppet fact that our applications can act upon.
* **--dir**: this is the directory that contains your `isolinux` directory. The `isolinux.cfg` file in this directory is parsed by `mkvm.rb` and is expected to have specific tokens that will be replaced.
* **--vlan**: this is the full name of the VLAN to which the VM will be assigned. You may need to wrap this option in quotes.

## User Defaults
If a file `.mkvm.yaml` exists in the user's home directory, it will be loaded and the values found therein will be used for defaults. These defauls can still be overridden by command-line switches.

```yaml
host: vcenter.example.com
dc: primary
cluster: production
username: administrator
ds_regex: encrypted
iso_store: ESX_ISO
url: https://ks.example.com/rhel6.ks
gateway: 192.168.1.1
netmask: 255.255.255.0
dns: 192.168.1.2,192.168.1.3
domain: example.com
app_env: development
vlan: Production
```

See `mkvm.yaml.sample` for a full example.

## Templates
mkvm knows about five pre-defined VM sizes:

| name | vCPU | Memory | /dev/sda |
| :----: | :----: | :------: | :--------: |
| tiny | 1 | 512 | 14GB |
| small | 1 | 1024 | 15GB |
| medium | 1 | 2048 | 15GB |
| large | 2 | 4096 | 15GB |
| xlarge | 2 | 8192 | 15GB |

## Examples
To create a tiny VM named foobar:
```shell
$ ./mkvm.rb -t tiny foobar
```
This assumes that a fully-qualified domain name for foobar is already defined in DNS.

To create a tiny VM named foobar with a specific IP address:
```shell
$ ./mkvm.rb -t tiny -i 192.168.100.5 foobar
```

To create a custom VM named foobar with 3 vCPUs, 3 GB RAM, a 30 GB /dev/sda, a specific IP address, and include a 100GB /dev/sdb disk:
```bash
$ ./mkvm.rb --custom 3,3072,31457280 -i 192.168.100.5 --sdb 104857600 foobar
```

## License
mkvm.rb is copyright 2014, CoverMyMeds, LLC and is released under the terms of the [GNU General Public License, version 2](http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt).
