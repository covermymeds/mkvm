class ISO < Mkvm

  attr_accessor :defaults
  def initialize
    @defaults = { 
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
    return opts, options
  end
end
