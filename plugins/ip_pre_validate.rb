class Ip_pre_validate < Plugin
  def self.pre_validate options
    if ! options[:gateway]
      octets = options[:ip].split('.')
      octets[-1] = '1'
      options[:gateway] = octets.join('.')
    end
  end
end
