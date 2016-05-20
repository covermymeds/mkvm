class ISO < Mkvm

  def defaults
    return { 
      :srcdir => File.dirname(__FILE__) + '/../isolinux',
      :outdir => ENV['PWD'] + '/iso',
      :make_iso => true,
    }
  end

  def optparse opts, options
    opts.separator 'ISO options:'
    opts.on( '--isolinux_remote_host REMOTE_HOSTNAME', "Remote host to fetch isolinux files") do |x|
      options[:isolinux_remote_host] = x
    end
    opts.on( '--srcdir DIR', "Directory containing isolinux templates (#{options[:srcdir]})") do |x|
      options[:srcdir] = x
    end
    opts.on( '--outdir DIR', "Directory in which to write the ISO (#{options[:outdir]})") do |x|
      options[:outdir] = x
    end
    opts.on( '--[no-]iso', "Build ISO (#{options[:make_iso]})") do |x|
      options[:make_iso] = x
    end
    #return opts, options
  end

  def execute options

    return if ! options[:make_iso]

    hostname = options[:hostname]
    kickstart = options[:ks_line]
    minor = options[:minor]

    # grab the dirname of the isolinux path
    outdir = File.realdirpath(options[:outdir])
    FileUtils.mkdir_p outdir

    isoname = "#{hostname}.iso"
    work_dir = File.realdirpath(ENV['PWD'] + "/mkvm")
    tmp_dir = "#{work_dir}/#{hostname}"
    FileUtils.mkdir_p tmp_dir

    # Fetch isolinux content.
    if options[:isolinux_remote_host]
      remote_path = "/var/satellite/rhn/kickstart/ks-rhel-x86_64-server-#{options[:major]}-#{options[:major]}.#{options[:minor]}/isolinux"

      require 'net/scp'
      Net::SCP.start(options[:isolinux_remote_host], ENV['USER']) do |scp|
        scp.download! remote_path, tmp_dir, options = { :recursive => true }
      end
    else
      # Copy the isolinux dir from local
      srcdir = File.realdirpath("#{options[:srcdir]}/#{options[:major]}/")
      FileUtils.cp_r srcdir, "#{tmp_dir}/isolinux"
    end

    # Insert our kickstart options
    text = IO.read( "#{tmp_dir}/isolinux/isolinux.cfg" )
    # RHEL6
    text.gsub!(/append initrd=initrd.img\n/, "append initrd=initrd.img #{kickstart}\n")
    # RHEL7
    text.gsub!(/.*menu default.*/, '')
    text.gsub!(/menu label \^Install Red Hat Enterprise Linux 7.#{minor}/, "menu label ^Install Red Hat Enterprise Linux 7.#{minor}\n  menu default")
    text.gsub!(/append initrd=initrd.img inst.stage2=hd:LABEL=RHEL-7.#{minor}\\x20Server.x86_64 quiet\n/, "append initrd=initrd.img #{kickstart}\n")
    IO.write( "#{tmp_dir}/isolinux/isolinux.cfg", text )

    system( "mkisofs -quiet -o #{outdir}/#{isoname} -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -J -R -V '#{hostname[0..31]}' #{tmp_dir}" )

    # clean up after ourselves
    FileUtils.rm_rf "#{tmp_dir}"
    FileUtils.chmod_R 0755, "#{outdir}/#{isoname}"
    debug( 'INFO', "#{outdir}/#{isoname} created" ) if options[:debug]
  end
end
