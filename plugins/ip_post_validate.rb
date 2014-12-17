class Ip_post_validate < Plugin
  # This class provides a few sanity checks on the IP address.
  # We run this as a post_validate so that pre-validate plugins might
  #   have an opportunity to manipulate the options we inspect here. 

  # NOTE: we fail hard in four events:
  # * an invalid IP address is supplied
  # * an invalid subnet mask is supplied
  # * an invalid gateway IP address is supplied
  # * the supplied IP address matches the supplied gateway address
  #
  # In all other events, we simply report a warning about potential
  # problems, but it's up to the user to not destroy their network.

  def self.post_validate options
    if options[:ip]
      if options[:ip] !~ Resolv::IPv4::Regex
        abort "ERROR: Invalid IP address #{options[:ip]}"
      end
    end

    mask_regex = /^[1-2]{1}[2,4,5,9]{1}[0,2,4,5,8]{1}\.[0-2]{1}[0,2,4,5,9]{1}[0,2,4,5,8]{1}\.[0-2]{1}[0,2,4,5,9]{1}[0,2,4,5,8]{1}\.[0-9]{1,3}$/
    if options[:subnet]
      if options[:netmask] !~ mask_regex
        abort "ERROR: Invalid subnet mask #{options[:subnet]}"
      end
    end

    if options[:gateway]
      if options[:gateway] !~ Resolv::IPv4::Regex
        abort "ERROR: Invalid gateway #{options[:gateway]}"
      end
    end

    if options[:ip] and options[:gateway]
      if options[:ip] == options[:gateway]
        abort "ERROR: IP cannot match gateway!"
      end
    end

    # compare the specified IP address with the lookup
    # for the requested hostname
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
