require "singleton"
require 'yaml'
require 'fileutils'

class BMF::Settings
  include Singleton

  SETTINGS_AND_DESCRIPTIONS = {
    :server_url => "Url of the BitMessage server to interface with.",
    :sig => "Signature line to attach to messages.",
    :default_send_address => "Default FROM address for messages.",
    :server_interface => "Internet interface to listen on.  Set to 0.0.0.0 to open up BMF to the network.  WARNING!!! Anyone who can access your IP can read/post/delete/etc.",
    :server_port => "Internet port to listen on.",
    :display_sanitized_html => "Show sanitized HTML minus scripts, css, and any non-inline images.",
    :sync_interval => "Frequency to sync inbox with PyBitmessage, in seconds.  Default 60",
    :user => "username for http basic authentication.  (You should be using https in conjunction with this!)",
    :password => "password for http basic authentication.  (You should be using https in conjunction with this!)",
    :https_server_key_file => "file for https key",
    :https_server_certificate_file => "file for https certificate",
    :mark_inbox_read => "Mark the message as read in PyBitmessage when it's retreived.  (Set to 1 to enable)"
  }

  DEFAULT_SETTINGS = {"server_url" => 'http://bmf:bmf@localhost:8442/', "display_sanitized_html" => 'no', 'server_interface' => "localhost" }

  VALID_SETTINGS = SETTINGS_AND_DESCRIPTIONS.keys

  HOME_DIR = ENV["HOME"] || ENV["HOMEPATH"]
  SETTINGS_DIR = ENV["BMF_SETTINGS"] || File.join(HOME_DIR, ".bitmessageforum")
  SETTINGS_FILE = File.join(SETTINGS_DIR, "settings.yml")

  def initialize
    Dir.mkdir(SETTINGS_DIR, 0700) if !File.directory? SETTINGS_DIR
    settings_filename = SETTINGS_FILE

    if !File.exists? (SETTINGS_FILE)
      puts "No existing settings.  Copying defaults into place."
      @settings = DEFAULT_SETTINGS
      persist
    end

    @settings = YAML.load_file(settings_filename)
  end
  
  def update(key, value)
    raise "Bad setting #{key}.  Allowed settings #{VALID_SETTINGS.inspect}" if !VALID_SETTINGS.include?(key.to_sym)
    @settings[key] = value

    BMF::XmlrpcClient.instance.initialize_client if key.to_sym == :server_url
  end

  def persist
    File.open(SETTINGS_FILE,'w',0600) do |out|
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
