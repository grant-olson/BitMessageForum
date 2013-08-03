require 'thread'

module BMF

  require_relative "bmf/lib/bmf.rb"
  require_relative "bmf/lib/alert.rb"

  def self.puts_and_alert msg
    puts msg
    Alert.instance << msg
  end

  def self.sync
    new_messages = MessageStore.instance.update
    Alert.instance.add_new_messages(new_messages)
    AddressStore.instance.update

  rescue Errno::ECONNREFUSED => ex
    puts_and_alert "Background sync.  Couldn't connect to PyBitmessage server.  Is it running with the API enabled? " 
  rescue JSON::ParserError => ex
    puts_and_alert "Couldn't background sync.  It seems like PyBitmessage is running but refused access.  Do you have the correct info in config/settings.yml? "
  rescue Exception => ex
    puts_and_alert "Background Sync failed with #{ex.message}"
  end

  def self.boot
    puts "Doing initial sync before starting..."
    sync
    Alert.instance.pop_new_messages # don't show new message alert on bood.

    Thread.new do

      while(1) do
        sync_interval = Settings.instance.sync_interval.to_i
        sync_interval = 60 if sync_interval == 0
        sleep(sync_interval)
        begin
          sync
        rescue Exception => ex
          msg = "Background sync faild with #{ex.message}"
          Alert.instance << msg
          puts msg
          puts ex.backtrace.join("\n")
        end
      end
      
    end

    BMF.run! do |server|
      settings = Settings.instance

      if (settings.https_server_key_file && settings.https_server_key_file != "") &&
          (settings.https_server_certificate_file && settings.https_server_certificate_file != "")

        puts "Requiring https..."
        ssl_options = {
          :cert_chain_file => settings.https_server_certificate_file,
          :private_key_file => settings.https_server_key_file,
          :verify_peer => false
        }
        server.ssl = true
        server.ssl_options = ssl_options
      else
        puts "NOT requiring https.  Traffic is unencrypted..."
      end
    end

  end

end
