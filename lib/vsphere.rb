class Vsphere < Mkvm

  def initialize
  end

  def defaults
    return {
      :username => ENV['USER'],
      :insecure => true,
      :upload_iso => true,
      :make_vm => true,
      :vlan => 'Production',
      :power_on => true,
    } 
  end

  def optparse opts, options
      opts.separator 'VSphere options:'
      opts.on( '-u', '--user USER', "vSphere user name (#{options[:username]})") do |x|
        options[:username] = x
      end
      opts.on( '-p', '--password PASSWORD', 'vSphere password') do |x|
        options[:password] = x
      end
      opts.on( '-H', '--host HOSTNAME', "vSphere host (#{options[:host]})") do |x|
        options[:host] = x
      end
      opts.on( '-D', '--dc DATACENTER', "vSphere data center (#{options[:dc]})") do |x|
        options[:dc] = x
      end
      opts.on( '-C', '--cluster CLUSTER', "vSphere cluster (#{options[:cluster]})") do |x|
        options[:cluster] = x
      end
      opts.on( '--[no-]insecure', "Do not validate vSphere SSL certificate (#{options[:insecure]})") do |x|
        options[:insecure] = x
      end
      opts.on( '--datastore DATASTORE', "vSphere datastore regex to use (#{options[:ds_regex]})") do |x|
        options[:ds_regex] = x
      end
      opts.on( '--isostore ISOSTORE', "vSphere ISO store to use (#{options[:iso_store]})") do |x|
        options[:isostore] = x
      end
      opts.separator 'VM options:'
      opts.on( '-t', '--template TEMPLATE', "VM template: small, medium, large, xlarge") do |x|
        options[:template] = x
      end
      opts.on( '--custom cpu,mem,sda', Array, 'CPU, Memory, and /dev/sda' ) do |x|
        options[:custom] = x
      end
      opts.on( '--sdb [10G{,/pub}]', 'Add /dev/sdb. Size and mount point optional.' ) do |x|
        options[:raw_sdb] = x || '10G'
      end
      opts.on( '--vlan VLAN', "VLAN (#{options[:vlan]})") do |x|
        options[:vlan] = x
      end
      opts.on( '--[no-]upload', "Upload the ISO to the ESX cluster (#{options[:upload_iso]})") do |x|
        options[:upload_iso] = x
      end
      opts.on( '--[no-]vm', "Build the VM (#{options[:make_vm]})") do |x|
        options[:make_vm] = x
      end
      opts.on( '--[no-]power', "Power on the VM after building it (#{options[:power_on]})") do |x|
        options[:power_on] = x
      end
      return opts, options
  end

  def validate options
    if options[:upload_iso] and options[:make_vm] and not options[:password]
      print 'Password: '
      options['password'] = STDIN.noecho(&:gets).chomp
      puts ''
    end
    return options
  end
end
