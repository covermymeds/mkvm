class Vm_clone < Mkvm

  def initialize
    @templates = {
      'small' => [1, '1G', '15G'],
      'medium' => [2, '2G', '15G'],
      'large' => [2, '4G', '15G'],
      'xlarge' => [2, '8G', '15G'],
    }

  end

  def defaults
    return {
      :username => ENV['USER'],
      :insecure => true,
      :upload_iso => true,
      :make_vm => true,
      #:vlan => 'Production',
      :power_on => true,
    } 
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
    abort '-t or --custom is required' unless options[:template] or options[:custom]
    if options[:template] and options[:custom]
      abort '-t and --custom are mutually exclusive'
    end

    if options[:template]
      options[:cpu], raw_mem, raw_sda = @templates[options[:template]]
    else
      options[:cpu], raw_mem, raw_sda = options[:custom]
    end

    # we accept human-friendly input, but need to deal with
    # Mebibytes for RAM and Kebibytes for disks
    options[:mem] = parse_size(raw_mem, 'M')
    options[:sda] = parse_size(raw_sda, 'K')

    if options[:raw_sdb]
      sdb_size, *sdb_path = options[:raw_sdb].split(/,/)
      options[:sdb] = parse_size(sdb_size, 'K')
      options[:sdb_path] = sdb_path[0]
    end

    debug( 'INFO', "CPU: #{options[:cpu]}" ) if options[:debug]
    debug( 'INFO', "Mem: #{options[:mem]} MiB" ) if options[:debug]
    debug( 'INFO', "sda: #{options[:sda]} KiB" ) if options[:debug]
    debug( 'INFO', "sdb: #{options[:sdb]} KiB" ) if options['sdb'] and options[:debug]
    debug( 'INFO', "sdb_path: #{options[:sdb_path]}" ) if options[:sdb_path] and options[:debug]
    #debug( 'INFO', "VLAN: #{options[:vlan]}" ) if options[:debug]

    if ! options[:network] and ! options[:dvswitch]
      abort "To properly configure the network interface you need a map 
in ~/.mkvm.yaml for both :dvswitch and :network.  These 
structures map Datacenter name to dvswitch UUID and subnet 
to VLAN name and dvportGroupKey.  The mappings looks something like: 
    
:dvswitch:
  'dc1': 'dvswitch1uuid'
  'dc2': 'dvswitch2uuid'
:portgroup:
  '192.168.20.0':
    name: 'Production'
    portgroup: 'dvportgroup1-number'
  '192.168.30.0':
    name: 'DMZ'
    portgroup: 'dvportgroup2-number'"
    end

    begin
      options[:network][options[:subnet]]['name']
    rescue
      abort "!! Invalid subnet !! Validate your subnet and dvswitch. "
    end

    if not options[:password]
      print 'Password: '
      options[:password] = STDIN.noecho(&:gets).chomp
      puts ''
    end
  end

  def execute options
    vim = RbVmomi::VIM.connect( { :user => options[:username], :password => options[:password], :host => options[:host], :insecure => options[:insecure] } ) or abort $!
    dc = vim.serviceInstance.find_datacenter(options[:dc]) or abort "vSphere data center #{options[:dc]} not found"
    debug( 'INFO', "Connected to datacenter #{options[:dc]}" ) if options[:debug]
    cluster = dc.hostFolder.children.find { |x| x.name == options[:cluster] } or abort "vSphere cluster #{options[:cluster]} not found"
    debug( 'INFO', "Found VMware cluster #{options[:cluster]}" ) if options[:debug]
    # select the datastore with the most available space
    datastore = dc.datastore.find_all { |x| x.name =~ /#{options[:ds_regex]}/ }.max_by{ |i| i.info.freeSpace }.name
    debug( 'INFO', "Selected datastore #{datastore}" ) if options[:debug]

    # Clone from Template VM
    src_vm = dc.find_vm("mitrhel6appservertemplate.cmmint.net")
    puts src_vm.config
    clone_spec = generate_clone_spec(src_vm.config, dc, options[:cpu], options[:mem], datastore, options[:network][options[:subnet]]['name'], cluster)
    clone_spec.customization = ip_settings(options) 

    if options[:debug]
      debug( 'INFO', "Building #{options[:hostname]} VM now" )
    end

    src_vm.CloneVM_Task(:folder => src_vm.parent, :name => options[:hostname], :spec => clone_spec).wait_for_completion

    # Setup anti-affinity rules if needed
    vc_affinity(dc, cluster, options[:hostname], options[:domain])
  end

  # Create or update anti-affinity rules to keep like VM on separate physical hosts
  def vc_affinity(dc, cluster, host, domain)
    short = host.split('.')[0]
    if hostnum = short =~ /([2-9]$)/
      Vm_drs.new(dc, cluster, short.chop, domain, hostnum).create
    end
  end

  # Populate the customization_spec with the new host details
  def ip_settings(settings)

    ip_settings = RbVmomi::VIM::CustomizationIPSettings.new(:ip => RbVmomi::VIM::CustomizationFixedIp(:ipAddress => settings[:ip]), :gateway => [settings[:gateway]], :subnetMask => settings[:netmask])
    ip_settings.dnsDomain = settings[:domain]

    global_ip_settings = RbVmomi::VIM.CustomizationGlobalIPSettings
    global_ip_settings.dnsServerList = settings[:dns].split(',')
    global_ip_settings.dnsSuffixList = [settings[:domain]]

    hostname = RbVmomi::VIM::CustomizationFixedName.new(:name => settings[:hostname].split('.')[0])
    linux_prep = RbVmomi::VIM::CustomizationLinuxPrep.new( :domain => settings[:domain], :hostName => hostname)
    adapter_mapping = [RbVmomi::VIM::CustomizationAdapterMapping.new("adapter" => ip_settings)]

    spec = RbVmomi::VIM::CustomizationSpec.new( :identity => linux_prep,
                                                :globalIPSettings => global_ip_settings,
                                                :nicSettingMap => adapter_mapping )

    return spec

  end

  # Populate the VM clone specification
  def generate_clone_spec(src_config, dc, cpus, memory, datastore, network, cluster)

    clone_spec = RbVmomi::VIM.VirtualMachineCloneSpec(:location => RbVmomi::VIM.VirtualMachineRelocateSpec, :template => false, :powerOn => false)
    clone_spec.config = RbVmomi::VIM.VirtualMachineConfigSpec(:deviceChange => Array.new, :extraConfig => nil)

    network = find_network(network, dc)
    card = src_config.hardware.device.find { |d| d.deviceInfo.label == "Network adapter 1" }
    begin
      switch_port = RbVmomi::VIM.DistributedVirtualSwitchPortConnection(
        :switchUuid => network.config.distributedVirtualSwitch.uuid,
        :portgroupKey => network.key
      )
      card.backing.port = switch_port
    rescue Exception => e
      puts e
      card.backing.deviceName = network.name
    end

    network_spec = RbVmomi::VIM.VirtualDeviceConfigSpec(:device => card, :operation => "edit")
    clone_spec.config.deviceChange.push network_spec

    clone_spec.config.numCPUs  = Integer(cpus)
    clone_spec.config.memoryMB = Integer(memory)

    clone_spec
  end

  def find_network(network, dc)
    puts network
    baseEntity = dc.network
    baseEntity.find { |f| f.name == network }
  end

  def execute_command_on_machine
    new_machine = PuppetX::Puppetlabs::Vsphere::Machine.new(name)
    machine = datacenter_instance.find_vm(new_machine.local_path)
    machine_credentials = {
      interactiveSession: false,
      username: resource[:create_command]['user'],
      password: resource[:create_command]['password'],
    }
    manager = vim.serviceContent.guestOperationsManager
    auth = RbVmomi::VIM::NamePasswordAuthentication(machine_credentials)
    handler = Proc.new do |exception, attempt_number, total_delay|
      Puppet.debug("#{exception.message}; retry attempt #{attempt_number}; #{total_delay} seconds have passed")
      # All exceptions in RbVmomi are RbVmomi::Fault, rather than the actual API exception
      # The actual exceptions come out in the message, so we parse them out
      case exception.message.split(':').first
      when 'GuestComponentsOutOfDate'
        raise Puppet::Error, 'VMware Tools is out of date on the guest machine'
      when 'InvalidGuestLogin'
        raise Puppet::Error, 'Incorrect credentials for the guest machine'
      when 'OperationDisabledByGuest'
        raise Puppet::Error, 'Remote access is disabled on the guest machine'
      when 'OperationNotSupportedByGuest'
        raise Puppet::Error, 'Remote access is not supported by the guest operating system'
      end
    end
    arguments = resource[:create_command].has_key?('arguments') ? resource[:create_command]['arguments'] : ''
    working_directory = resource[:create_command].has_key?('working_directory') ? resource[:create_command]['working_directory'] : '/'
    spec = RbVmomi::VIM::GuestProgramSpec(
      programPath: resource[:create_command]['command'],
      arguments: arguments,
      workingDirectory: working_directory,
    )
    with_retries(:max_tries => 10,
                 :handler => handler,
                 :base_sleep_seconds => 5,
                 :max_sleep_seconds => 15,
                 :rescue => RbVmomi::Fault) do
      manager.authManager.ValidateCredentialsInGuest(vm: machine, auth: auth)
      response = manager.processManager.StartProgramInGuest(vm: machine, auth: auth, spec: spec)
      Puppet.info("Ran #{resource[:create_command]['command']}, started with PID #{response}")
    end
  end

end
