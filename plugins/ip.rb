class Ip < Plugin
  # This class provides a few sanity checks on the IP address.

  # This class also exposes a new option: 'gateway_octet'
  # which can be used to define the gateway IP address

  def self.defaults
    return { :gateway_octet => '1' }
  end

  def self.optparse opts, options
    opts.separator 'IP options:'
    opts.on( '-G', '--gw-octet', "Gateway octet (#{options[:gateway_octet]})") do |x|
      options[:gateway_octet] = x
    end
  end

  def self.pre_validate options
    # if we have an IP address (whether specified on the command line
    # or injected by other plugins), let's compare that with a
    # DNS lookup on the specified hostname
    if options[:ip]
      begin
        resolved_ip = Resolv.getaddress( options[:hostname] )
      rescue Resolv::ResolvError
        resolved_ip = false
      end
      if resolved_ip and (resolved_ip != options[:ip])
        self.debug( 'WARN', "#{options[:ip]} does not match DNS for #{options[:hostname]}" )
      end
    end

    # if we don't have a gateway address we'll compute one
    if ! options[:gateway]
      octets = options[:ip].split('.')
      octets[-1] = options[:gateway_octet]
      options[:gateway] = octets.join('.')
    end
  end

  # We run this as a post_validate so that pre-validate plugins might
  #   have an opportunity to manipulate the options we inspect here. 

  # NOTE: we fail hard in five events:
  # * no IP address is defined
  # * an invalid IP address is supplied
  # * an invalid subnet mask is supplied
  # * an invalid gateway IP address is supplied
  # * the supplied IP address matches the supplied gateway address
  #
  # In all other events, we simply report a warning about potential
  # problems, but it's up to the user to not destroy their network.

  def self.post_validate options
    if ! options[:ip]
      about "ERROR: No IP address specified!"
    end

    if options[:ip] !~ Resolv::IPv4::Regex
      abort "ERROR: Invalid IP address #{options[:ip]}"
    end

    mask_regex = /^[1-2]{1}[2,4,5,9]{1}[0,2,4,5,8]{1}\.[0-2]{1}[0,2,4,5,9]{1}[0,2,4,5,8]{1}\.[0-2]{1}[0,2,4,5,9]{1}[0,2,4,5,8]{1}\.[0-9]{1,3}$/
    if options[:subnet]
      if options[:netmask] !~ mask_regex
        abort "ERROR: Invalid subnet mask #{options[:subnet]}"
      end
    end

    if options[:gateway] !~ Resolv::IPv4::Regex
      abort "ERROR: Invalid gateway #{options[:gateway]}"
    end

    if options[:ip] == options[:gateway]
      abort "ERROR: IP cannot match gateway!"
    end

    # compare the specified IP address with the lookup
    # for the requested hostname
    # This is the same check as perfomed in the pre_validate method.
    # We repeat it here because we *do* have an IP address at this point
    # whereas we may not have prior
    begin
      resolved_ip = Resolv.getaddress( options[:hostname] )
    rescue Resolv::ResolvError
      resolved_ip = false
    end
    if resolved_ip and (resolved_ip != options[:ip])
      self.debug( 'WARN', "#{options[:ip]} does not match DNS for #{options[:hostname]}" )
    end

    begin
      fqdn = Socket.gethostbyname( options[:hostname] ).first
    rescue SocketError
      fqdn = false
    end
    begin
      resolved_name = Resolv.getname( options[:ip] )
    rescue Resolv::ResolvError
      resolved_name = false
    end
    if resolved_name and (resolved_name != fqdn)
      self.debug( 'WARN', "#{options[:ip]} already assigned to #{resolved_name}" )
    end
  end
end
