require "singleton"
require 'yaml'
require 'fileutils'

class Settings
  include Singleton

  VALID_SETTINGS = [:server_url,
                    :sig,
                    :default_send_address,
                    :server_interface,
                    :server_port,
                    :display_sanitized_html]

  SETTINGS_FILE = File.expand_path("../../config/settings.yml", __FILE__)
  SAMPLE_FILE = File.expand_path("../../config/settings.yml.sample", __FILE__)

  def initialize

    if !File.exists? SETTINGS_FILE
      puts "No settings.  Copying sample file into place."
      FileUtils.copy SAMPLE_FILE, SETTINGS_FILE
      File.chmod 0600, SETTINGS_FILE
    end

    @settings = YAML.load_file(SETTINGS_FILE)
  end
  
  def update(key, value)
    raise "Bad setting #{key}.  Allowed settings #{VALID_SETTINGS.inspect}" if !VALID_SETTINGS.include?(key.to_sym)
    @settings[key] = value

    XmlrpcClient.instance.initialize_client if key.to_sym == :server_url
  end

  def persist
    File.open(SETTINGS_FILE,'w') do |out|
      out.write(@settings.to_yaml)
    end
  end

  def method_missing(meth, *args)
    if args == [] and VALID_SETTINGS.include?(meth)
      ret = @settings[meth.to_s]
      ret = nil if ret == ""
      return ret
    else
      super
    end
  end

end
