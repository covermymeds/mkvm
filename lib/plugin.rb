class Plugin
  def self.defaults
    return {}
  end

  def self.debug prefix, message
    puts "#{prefix}: #{message}"
  end

  def self.optparse opts, options
  end

  def self.pre_validate options
  end

  def self.post_validate options
  end

  def self.pre_vm options
  end

  def self.post_vm options
  end
end
