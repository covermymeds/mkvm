class Mkvm

  def initialize
  end

  def defaults
  end

  def optparse opts, options
    return opts, options
  end

  def validate options
    return options
  end

  def execute options
  end

  def debug prefix, message
    puts "#{prefix}: #{message}"
  end
end
