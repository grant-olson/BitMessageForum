require "singleton"
require 'yaml'
require 'fileutils'

class Settings
  include Singleton

  def initialize
    settings_file = File.expand_path("../../config/settings.yml", __FILE__)
    sample_file = File.expand_path("../../config/settings.yml.sample", __FILE__)

    if !File.exists? settings_file
      puts "No settings.  Copying sample file into place."
      FileUtils.copy sample_file, settings_file
      File.chmod 0600, settings_file
    end

    @settings = YAML.load_file(settings_file)
  end
  
  def method_missing(meth, *args)
    setting = meth.to_s
    if args ==[] and @settings.has_key? setting
      return @settings[setting]
    else
      super
    end
  end

end
