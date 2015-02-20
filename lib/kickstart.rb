class Kickstart < Mkvm

  def defaults 
    return { :major => '6', :ksdevice => 'eth0' }
  end

  def optparse opts, options
    opts.separator 'Kickstart options:'
    opts.on( '-r', '--major VERSION', "Major OS release to use (#{options['major']})") do |x|
      options[:major] = x
    end
    opts.on( '--url URL', "Kickstart URL (#{options[:url]})") do |x|
      options[:url] = x
    end
    opts.on( '-k', '--ksdevice TYPE', "ksdevice type to use (#{options[:ksdevice]})") do |x|
      options[:ksdevice] = x
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
    opts.on( '--app-env APP_ENV', "APP_ENV (#{options[:app_env]})") do |x|
      options[:app_env] = x
    end
    opts.on( '--app-id APP_ID', 'APP_ID') do |x|
      options[:app_id] = x
    end
    opts.on( '--extra "ONE=1 TWO=2"', 'extra args to pass to boot line') do |x|
      options[:extra] = x
    end
  end

  def validate(options)
    # handle differences between RHEL6 and RHEL7
    if options[:major].to_i == 7
      # Generate the proper Nameserver string based on major_rel
      nameserver_string = options[:dns].split(',').collect { |x| "nameserver=#{x}" }.join(" ")
      # RHEL7 does away with ethX device names
      options[:ksdevice] = 'link'
    else
      nameserver_string = "dns=#{options[:dns]}"
    end

    # if given a short hostname and a domain name,
    # concatenate the two to create the hostname.
    # otherwise, accept what was given to us here
    if (options[:hostname] !~ /\./) and (options[:domain])
      options[:hostname] = "#{options[:hostname]}.#{options[:domain]}"
    end

    # finally, let's build up our KS line and add it to the options hash
    ks_line="ks=#{options[:url]} noverifyssl ksdevice=#{options[:ksdevice]} ip=#{options[:ip]} netmask=#{options[:netmask]} gateway=#{options[:gateway]} hostname=#{options[:hostname]} #{nameserver_string} APP_ENV=#{options[:app_env]}"
    # add the APP_ID, if one was supplied
    ks_line << " APP_ID=#{options[:app_id]}" if options[:app_id]
    ks_line << " SDB" if options[:sdb]
    ks_line << "=#{options[:sdb_path]}" if options[:sdb_path]
    ks_line << " #{options[:extra]}" if options[:extra]

    options[:ks_line] = ks_line

    debug( 'INFO', "IP: #{options[:ip]}" ) if options[:debug]
    debug( 'INFO', "Netmask: #{options[:netmask]}" ) if options[:debug]
    debug( 'INFO', "Gateway: #{options[:gateway]}" ) if options[:debug]
    debug( 'INFO', "Kickstart line: #{options[:ks_line]}" ) if options[:debug]
  end 
end
