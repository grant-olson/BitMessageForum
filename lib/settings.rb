require "singleton"
require 'yaml'
require 'fileutils'

class Settings
  include Singleton

  SETTINGS_AND_DESCRIPTIONS = {
    :server_url => "Url of the BitMessage server to interface with.",
                    :sig => "Signature line to attach to messages.",
                    :default_send_address => "Default FROM address for messages.",
                    :server_interface => "Internet interface to listen on.  Set to 0.0.0.0 to open up BMF to the network.  WARNING!!! Anyone who can access your IP can read/post/delete/etc.",
                    :server_port => "Internet port to listen on.",
                    :display_sanitized_html => "Show sanitized HTML minus scripts, css, and any non-inline images."
  }

  VALID_SETTINGS = SETTINGS_AND_DESCRIPTIONS.keys

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
