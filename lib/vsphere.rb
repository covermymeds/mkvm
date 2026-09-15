class Vsphere < Mkvm

  def initialize
    @templates = {
      'small'  => [1, '1G'],
      'medium' => [2, '2G'],
      'large'  => [2, '4G'],
      'xlarge' => [2, '8G'],
    }

  end

  def defaults
    return {
      :username => ENV['USER'],
      :insecure => true,
      :make_vm => true,
      :wait => 300,    # 5 mins
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
      opts.on( '--clusterregex CLUSTER', "vSphere cluster regex (#{options[:cluster_regex]})") do |x|
        options[:cluster_regex] = x
      end
      opts.on( '-F', '--folder FOLDER', "vSphere vm folder (#{options[:folder]})") do |x|
        options[:folder] = x
      end
      opts.on( '--[no-]insecure', "Do not validate vSphere SSL certificate (#{options[:insecure]})") do |x|
        options[:insecure] = x
      end
      opts.on( '--datastore DATASTORE', "vSphere datastore to use (#{options[:datastore]})") do |x|
        options[:datastore] = x
      end
      opts.on( '--dsregex DATASTORE', "vSphere datastore regex to use (#{options[:ds_regex]})") do |x|
        options[:ds_regex] = x
      end
      opts.separator 'VM options:'
      opts.on( '--[no-]vm', "Build the VM (#{options[:make_vm]})") do |x|
        options[:make_vm] = x
      end
      opts.on( '-t', '--template TEMPLATE', "VM template: small, medium, large, xlarge") do |x|
        options[:template] = x
      end
      opts.on( '--cpu CPU', 'Number of cpus' ) do |x|
        options[:cpu] = x
      end
      opts.on( '--virthost', 'Host is used for nested virtualization.' ) do
        options[:virt] = true
      end
      opts.on( '--memory RAM', 'Memory in GB' ) do |x|
        options[:memory] = x
      end
      opts.on( '--disk [10G{,/pub}]', 'Add another disk. Size and mount point optional. Can be used more than once.' ) do |x|
        raw_disk = x || '10G,/pub'
        list_disk = raw_disk.split ','

        # create the array if it doesn't exist already
        options[:disks] ||= []

        # append to it
        options[:disks] << { size: parse_size(list_disk[0]), path: list_disk[1] }
      end
      opts.on( '--sourcevm SOURCEVM', 'Source VM from which to clone new VM.' ) do |x|
        options[:source_vm] = x
      end
      opts.on( '-i', '--ip ADDRESS', 'IP address') do |x|
        options[:ip] = x
      end
      opts.on( '-g', '--gateway GATEWAY', 'Gateway address') do |x|
        options[:gateway] = x
      end
      opts.on( '-m', '--netmask NETMASK', "Subnet mask (#{options[:netmask]})") do |x|
        options[:netmask] = x
      end
      opts.on( '-d', '--dns DNS1{,DNS2,...}', "DNS server(s) to use (#{options[:dns]})") do |x|
        options[:dns] = x
      end
      opts.on( '--domain DOMAIN', "DNS domain to append to hostname (#{options[:domain]})") do |x|
        options[:domain] = x
      end
      opts.on( '--annotation ANNOTATION', "Annotation for VM (#{options[:annotation]})") do |x|
        options[:annotation] = x.to_s
      end
      opts.on( '--wait SECONDS', "Time to wait for IP to be assigned to VM (#{options[:wait]})" ) do |x|
        options[:wait] = x.to_i.abs
      end
  end

  # this helper method converts unit sizes from human readable to machine usable
  def parse_size(size, target_unit = 'K')
    if size =~ /^[0-9.]+$/
      # size was an integer or a float
      # assume user knows what they are doing
      return size
    end
    # otherwise, get the input base unit
    unit = size[-1,1]
    input_size = size.chomp(unit)
    # if the input unit is the same as the target unit,
    # give them back what they gave us
    if unit == target_unit
      return input_size.to_int
    end
    # convert input size to Kibibytes
    @hash = { 'K' => 1, 'M' => 1024, 'G' => 1048576, 'T' => 1073741824 }
    if @hash.include? unit
      k = size.to_f*@hash[unit]
    else
      abort "Unit #{unit} makes no sense!"
    end
    # compute output size
    o = (k / @hash[target_unit]).to_int
    return o
  end


  def validate options
    abort '-t or --cpu and --memory are required' unless options[:template] or (options[:cpu] and options[:memory])
    if options[:template] and (options[:cpu] and option[:memory])
      abort '-t and --cpu/--memory are mutually exclusive'
    end

    abort 'Either --datastore or --dsregex is required' if options[:datastore].nil? and options[:ds_regex].nil?

    abort 'Either --cluster or --clusterregex is required' if options[:cluster].nil? and options[:cluster_regex].nil?


    if options[:template]
      options[:cpu], options[:memory] = @templates[options[:template]]
    end

    # We accept human-friendly input, but need to deal with
    # Mebibytes for RAM and Kebibytes for disks
    options[:memory] = parse_size(options[:memory], 'M')

    debug( 'INFO', "CPU: #{options[:cpu]}" ) if options[:debug]
    debug( 'INFO', "Mem: #{options[:memory]} MiB" ) if options[:debug]

    invalid_mounts = [ '/', '/boot', '/tmp', '/opt', '/var' ]
    if options[:disks]
      options[:disks].each do |disk|
        abort "#{disk[:path]} is an existing mount" if invalid_mounts.include? disk[:path]
        debug( 'INFO', "disk: #{disk[:size]} KiB with path #{disk[:path]}" )
        invalid_mounts << disk[:path]
      end
    end

    if ! options[:network]
      abort "To properly configure the network interface you need a map
in ~/.mkvm.yaml for :network. This structure maps subnet to dvportgroup name.
The mapping looks something like:

:network:
  '192.168.20.0':
    name: 'Production'
  '192.168.30.0':
    name: 'DMZ'"
    end

    begin
      options[:network][options[:subnet]]['name']
    rescue
      abort "!! Invalid subnet !! Validate your subnet configuration. "
    end

    if options[:make_vm] and not options[:password]
      print 'Password: '
      options[:password] = STDIN.noecho(&:gets).chomp
      puts ''
    end

    if options[:annotation]
      if not options[:annotation].is_a?(String)
        abort "!! Invalid annotation !! Validate your annotation is a String. "
      end

      if options[:annotation].to_s.size < 1
        abort "!! Invalid annotation !! Please provide an annotation string. "
      end
    end
  end

  def execute options

    vim = RbVmomi::VIM.connect( { :user => options[:username], :password => options[:password], :host => options[:host], :insecure => options[:insecure] } ) or abort $!
    dc = vim.serviceInstance.find_datacenter(options[:dc]) or abort "vSphere data center #{options[:dc]} not found"
    debug( 'INFO', "Connected to datacenter #{options[:dc]}" ) if options[:debug]
    
    #select the vsphere cluster to use
    if options[:cluster].nil?
      cluster = dc.hostFolder.children.find { |x| x.name =~ /#{options[:cluster_regex]}/ } or abort "vSphere cluster regex #{options[:cluster_regex]} not found"
    else
      cluster = dc.hostFolder.children.find { |x| x.name == options[:cluster] } or abort "vSphere cluster #{options[:cluster]} not found"
    end 
    rp = cluster.resourcePool
    debug( 'INFO', "Found VMware cluster #{cluster}" ) if options[:debug]

    #select the datastore to use
    if options[:datastore].nil?
      ds_name = dc.datastore.find_all { |x| x.name =~ /#{options[:ds_regex]}/ }.max_by{ |i| i.info.freeSpace }.name
    else
      ds_name = options[:datastore]
    end
    debug( 'INFO', "Selected datastore: #{ds_name}" ) if options[:debug]

    if options[:folder]
      vmFolder = dc.vmFolder.children.find { |x| x.name == options[:folder] } or abort "vSphere vmFolder #{options[:folder]} not found"
    else
      vmFolder = dc.vmFolder
    end

    options[:disks] || options[:disks] = []

    # Generate the clone spec
    source_vm = dc.find_vm("#{options[:source_vm]}") or abort "Failed to find source vm: #{options[:source_vm]}"
    clone_spec = generate_clone_spec(source_vm.config, dc, rp, options[:cpu], options[:memory],
                                     ds_name, options[:network][options[:subnet]]['name'],
                                     cluster, options[:disks], options[:extra], options[:virt], options[:annotation])

    clone_spec.customization = ip_settings(options[:ip], options[:gateway], options[:netmask], options[:domain], options[:dns], options[:hostname])

    if options[:make_vm]
      debug( 'INFO', "Cloning #{options[:source_vm]} to new VM: #{options[:hostname]}" ) if options[:debug]
      new_vm = source_vm.CloneVM_Task(:folder => vmFolder, :name => options[:hostname], :spec => clone_spec).wait_for_completion
      if new_vm
        wait_for_ip(new_vm, options[:wait], options)
      else
        puts "ERROR: unable to create new VM"
        exit 1
      end
    else
      puts "*** NOOP *** Cloning #{options[:source_vm]} to new VM: #{options[:hostname]}"
      exit
    end

    # Setup anti-affinity rules if needed
    begin
      vc_affinity(dc, cluster, vmFolder, options[:hostname], options[:domain])
    rescue
      puts "Failed to create anti-affinity rule for #{options[:hostname]}"
    end

  end

  # Wait for the ip address to be assigned by VM before returning
  def wait_for_ip(new_vm, wait, options)
    puts "Waiting for IP address to be obtained by VM..."
    poll_interval = 10
    while new_vm.guest_ip.nil? && wait > 0
      debug( 'INFO', "Waiting for IP... #{wait} seconds remain" ) if options[:debug]
      wait = wait - poll_interval
      sleep poll_interval
    end
    if new_vm.guest_ip.nil?
      puts "ERROR: unable to obtain IP address for VM: #{options[:hostname]}"
    else
      puts "Obtained IP address: #{new_vm.guest_ip}"
    end
  end

  def vc_affinity(dc, cluster, folder, host, domain)
    short = host.split('.')[0]
    search_path = folder.name.eql?('vm') ? "" : "#{folder.name}"
    if hostnum = short =~ /([2-9]$)/
      Vm_drs.new(dc, cluster, search_path, short.chop, domain, hostnum).create
    end
  end

    # Populate the customization_spec with the new host details
  def ip_settings(ip, gateway, netmask, domain, dns, hostname)

    ip_settings = RbVmomi::VIM::CustomizationIPSettings.new(:ip => RbVmomi::VIM::CustomizationFixedIp(:ipAddress => ip), :gateway => [gateway], :subnetMask => netmask)
    ip_settings.dnsDomain = domain

    global_ip_settings = RbVmomi::VIM.CustomizationGlobalIPSettings
    global_ip_settings.dnsServerList = dns.split(',')
    global_ip_settings.dnsSuffixList = [domain]

    hostname = RbVmomi::VIM::CustomizationFixedName.new(:name => hostname.split('.')[0])
    linux_prep = RbVmomi::VIM::CustomizationLinuxPrep.new( :domain => domain, :hostName => hostname)
    adapter_mapping = [RbVmomi::VIM::CustomizationAdapterMapping.new("adapter" => ip_settings)]

    spec = RbVmomi::VIM::CustomizationSpec.new( :identity => linux_prep,
                                                :globalIPSettings => global_ip_settings,
                                                :nicSettingMap => adapter_mapping )
    return spec
  end

   # Populate the VM clone specification
  def generate_clone_spec(source_config, dc, resource_pool, cpus, memory, ds_name, network, cluster, disks, extra, virt, annotation)

    datastore = dc.datastore.find { |ds| ds.name == ds_name }
    clone_spec = RbVmomi::VIM.VirtualMachineCloneSpec(:location => RbVmomi::VIM.VirtualMachineRelocateSpec(:pool => resource_pool, :datastore => datastore),
                                                      :template => false, :powerOn => true)
    clone_spec.config = RbVmomi::VIM.VirtualMachineConfigSpec(:deviceChange => Array.new, :extraConfig => Array.new)

    # Network device
    card = source_config.hardware.device.find { |d| d.deviceInfo.label == "Network adapter 1" }
    card.backing.port = get_switch_port(network, dc)
    network_spec = RbVmomi::VIM.VirtualDeviceConfigSpec(:device => card, :operation => "edit")
    clone_spec.config.deviceChange.push network_spec

    # CPU and RAM
    clone_spec.config.numCPUs  = Integer(cpus)
    clone_spec.config.memoryMB = Integer(memory)
    clone_spec.config.nestedHVEnabled = !!virt

    #Annotation
    clone_spec.config.annotation = annotation

    # Multiple disk support
    controllerkey = 100
    # start on sdb
    disk_dev = 'sdb'
    disk_index = 1
    disks.each do |disk|
      # retrieve the SCSI device
      source_config.hardware.device.each { |device|
        if device.deviceInfo.summary =~ /SCSI/
          controllerkey = device.key
        end
      }
      disk_spec = disk_config(ds_name, controllerkey, disk[:size], disk_index)
      clone_spec.config.deviceChange.push disk_spec

      # add path to guestinfo if disk path is not nil
      if disk[:path]
        clone_spec.config.extraConfig << { :key => "guestinfo.#{disk_dev}_path", :value => disk[:path] }
      end

      # increment disk dev and index
      disk_dev = disk_dev.next
      disk_index += 1
    end

    # Remove the cdrom
    cdrom = source_config.hardware.device.detect { |x| x.deviceInfo.label == "CD/DVD drive 1" }
    if not cdrom.nil?
      clone_spec.config.deviceChange.push RbVmomi::VIM.VirtualDeviceConfigSpec(:operation=>:remove, :device=> cdrom)
    end

    # Extra config for customizing the VM on first boot.
    if not extra.to_s.empty?
      extra.split.each_index { |index|
        clone_spec.config.extraConfig << { :key => "guestinfo.#{index.to_s}", :value => extra.split[index] }
      }
    end

    return clone_spec
  end

  def get_switch_port(network, dc)
    baseEntity = dc.network
    network_object = baseEntity.find { |f| f.name == network }
    RbVmomi::VIM.DistributedVirtualSwitchPortConnection(
      :switchUuid => network_object.config.distributedVirtualSwitch.uuid,
      :portgroupKey => network_object.key
    )
  end

  def disk_config(datastore, controllerkey, size, index)
    disk = {
            :operation     => :add,
            :fileOperation => :create,
            :device        => RbVmomi::VIM.VirtualDisk(
              :key     => index,
              :backing => RbVmomi::VIM.VirtualDiskFlatVer2BackingInfo(
                :fileName        => "[#{datastore}]",
                :diskMode        => :persistent,
                :thinProvisioned => false,
              ),
              :controllerKey => controllerkey,
              :unitNumber    => index,
              :capacityInKB  => size,
            )
          }
    return disk
  end

end
