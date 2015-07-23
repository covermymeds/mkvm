class ISO < Mkvm

  def defaults
    return { 
      :srcdir => './isolinux',
      :outdir => './iso',
      :make_iso => true,
    }
  end

  def optparse opts, options
    opts.separator 'ISO options:'
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

    # grab the dirname of the isolinux path
    srcdir = File.realdirpath("#{options[:srcdir]}/#{options[:major]}/")
    outdir = File.realdirpath(options[:outdir])

    isoname = "#{hostname}.iso"
    work_dir = File.realdirpath("#{options[:dir]}/tmp")
    tmp_dir = "#{work_dir}/#{hostname}"

    # TODO: handle exceptions
    FileUtils.mkdir_p tmp_dir

    # create the ISO template directory
    FileUtils.cp_r srcdir, "#{tmp_dir}/isolinux"

    text = IO.read( "#{tmp_dir}/isolinux/isolinux.cfg" )
    text.gsub!(/KICKSTART_PARMS/, options[:ks_line])
    IO.write( "#{tmp_dir}/isolinux/isolinux.cfg", text )
    system( "mkisofs -quiet -o #{outdir}/#{isoname} -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -J -R -V '#{hostname[0..32]}' #{tmp_dir}" )
    # clean up after ourselves
    FileUtils.rm_rf "#{tmp_dir}"
    FileUtils.chmod_R 0755, "#{outdir}/#{isoname}"
    debug( 'INFO', "#{outdir}/#{isoname} created" ) if options[:debug]
  end
end
