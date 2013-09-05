require 'sinatra/base'
require 'sinatra/reloader'
require 'sinatra/cookies'

require 'erb'

require 'haml'
require 'rdiscount'

require_relative 'message_store.rb'
require_relative 'address_store.rb'
require_relative 'thread_status.rb'
require_relative 'message.rb'
require_relative 'settings.rb'
require_relative 'folder.rb'

require 'sanitize'

class BMF::BMF < Sinatra::Base
  helpers Sinatra::Cookies

  helpers do

    def base58decode addr
      alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
      num = 0
      base = alphabet.length
      power = addr.length - 1

      addr.each_char do |char|
       num += alphabet.index(char) * (base ** power)
        power -= 1
      end
      num
    end

    def verify_checksum addr
      decoded_int = base58decode addr
      hex = decoded_int.to_s(16)
      hex = "0" + hex if hex.length % 2 != 0

      unpacked_number = [hex].pack('H*')
      main_number = unpacked_number[0..-5]
      checksum = unpacked_number[-4..-1]

      digest_1 = Digest::SHA512.new.update(main_number).digest
      digest_2 = Digest::SHA512.new.update(digest_1).digest

      return digest_2[0..3] == checksum
    end

    def verify_address addr
      if addr[0..2] == "BM-"
        addr = addr[3..-1]
      end

      verify_checksum(addr)
    end

    def safe_html html
      local_images_only = Sanitize::Config::RELAXED.dup
      local_images_only[:protocols]["img"]["src"] = ["data"]

      Sanitize.clean(html.force_encoding("UTF-8"), local_images_only)
    end
    
    # If we've got some html, make it safe
    def safe_text text
      return "" if text.nil?
      
      markdown_content_type = "# Content-Type: text/markdown"
      starts_with_markdown = text.strip.start_with? markdown_content_type
      if (not /<(a |img |ol|ul|li|h[1-6]|p|div|span)[^<]*>/.match(text)) && !starts_with_markdown
        return "<blockquote>" + CGI::escape_html(text).gsub("\n","<br />\n") + "</blockquote>"
      end

      if BMF::Settings.instance.display_sanitized_html != 'yes'
        return "<blockquote>" + CGI::escape_html(text).gsub("\n", "<br />\n")  + "</blockqoute>"
      end

      if text.strip.start_with? markdown_content_type
        text = RDiscount.new(text.sub(markdown_content_type, "")).to_html
      end

      safe_html(text)
      
    end

    # Customizable escape.  CGI.escape doesn't always do what we want.
    # We also need to escape the first period so we can have a subject
    # of '.'
    def full_escape str
      str = ERB::Util.url_encode(str)

      if str[0] && str[0] == "."
        str = "%2E" + str[1..-1]
      end

      str
    end
  end
  

  set :server, 'thin'
  set :root, File.expand_path("../../", __FILE__)
  set :layout, :layout

  settings = BMF::Settings.instance
  set :bind, settings.server_interface if settings.server_interface
  set :port, settings.server_port if settings.server_port

  configure :development do
    register Sinatra::Reloader
  end

  if (settings.user && settings.user != "")
    if (settings.password && settings.password != "")
      puts "Requiring http basic authentication..."
      use Rack::Auth::Basic, "Current BMF settings require authentication" do |username, password|
        username == settings.user and password == settings.password
      end
    else
      puts "You specified a username but no password! Refusing to use http basic authentication..."
    end
  end
  
  get "/", :provides => :html do
    haml :home
  end

  def load_settings
    @settings = {}

    BMF::Settings::VALID_SETTINGS.each do |key|
      @settings[key] = BMF::Settings.instance.send(key)
    end
  end

  get "/configuring-pybitmessage/", :provides => :html do
    haml :couldnt_reach_pybitmessage
  end

  get "/https-quick-start/", :provides => :html do
    haml :https_quick_start
  end

  get "/json/search_addresses/", :provides => :json do
    ss = params['search_string'].downcase

    matches = []
    BMF::AddressStore.instance.addresses.each_pair do |address, address_info|
      if address.downcase.include?(ss) || address_info['label'].downcase.include?(ss)
        matches << {:label => address_info['label'], :address => address }
      end
    end

    { :matching_addresses => matches}.to_json
  end

  get "/json/new_messages/", :provides => :json do
    new_message_count = BMF::Alert.instance.peek_new_messages

    new_folders = []
    if new_message_count > 0
      ["inbox", "chans", "lists"].each do |folder|
        if BMF::Folder.new(folder).new_messages?
          new_folders << folder
        end
      end
    end
    
    {:new_messages => new_message_count, :new_folders => new_folders}.to_json
  end
  
  get "/addressbook/", :provides => :html do
    @addresses = BMF::AddressStore.instance.address_book
    haml :addressbook
  end

  get "/identities/", :provides => :html do
    @addresses = BMF::AddressStore.instance.identities
    haml :identities
  end

  post "/identities/new/", :provides => :html do
    if params[:label]
      label = Base64.encode64(params[:label])
      response = BMF::XmlrpcClient.instance.createRandomAddress label
      if BMF::XmlrpcClient.is_error? response
        halt(500, "Couldn't create address: #{response}")
      else
        haml("Created random address #{response} with label #{params[:label]}")
      end
    elsif params[:passphrase]
      passphrase = Base64.encode64(params[:passphrase])
      response = BMF::XmlrpcClient.instance.createDeterministicAddresses passphrase
      if BMF::XmlrpcClient.is_error? response
        halt(500, "Couldn't create address: #{response}")
      else
        addresses = JSON.parse(response)['addresses']
        if addresses.empty?
          haml("Address already exists")
        else
          haml("Created address #{addresses.join(', ')}")
        end
      end
    else
      raise "Bad submission"
    end
    
  end
  
  get "/settings/", :provides => :html do
    load_settings
    haml :settings
  end

  post "/settings/update", :provides => :html do
    params.each_pair do |key, value|
      BMF::Settings.instance.update(key,value)
    end
    BMF::Settings.instance.persist

    @flash = "BMF::Settings updated!"

    load_settings
    haml :settings
  end

  post "/settings/mark_all_read", :provides => :html do
    BMF::ThreadStatus.instance.mark_all_read
    redirect "/settings/"
  end

  def init_compose
    @to = params[:to]
    @from = params[:from]
    @subject = params[:subject]

    @goto = params[:goto] || request.referrer

    if (@from.nil? || @from == "") && BMF::Settings.instance.default_send_address
      @from = BMF::Settings.instance.default_send_address
    end
    
    if params[:reply_to]
      @message = "&nbsp\n------------------------------------------------------\n" + BMF::MessageStore.instance.messages[params[:reply_to]]['message']
    else
      @message = params[:message]
    end
    
    @message = "" if @message.nil?
    if BMF::Settings.instance.sig && (params[:message].nil? || params[:message] == "")
      @message = "&nbsp;\n" + BMF::Settings.instance.sig + "\n" + @message
    end
  end
  
  get "/messages/compose/", :provides => :html do
    init_compose
    haml :compose
  end

  def check_send res
    if BMF::XmlrpcClient.is_error? res
      BMF::Alert.instance << "BACKGROUND SEND FAILED! #{res}"
    else
      BMF::Alert.instance << "Background send seemed to finish successfully"
    end
  end
  

  post "/messages/send/", :provides => :html do
    to = params[:to]
    from = params[:from]
    subject = Base64.encode64(params[:subject])
    message = Base64.encode64(params[:message])
    broadcast = params[:broadcast]

    if !verify_address(to) && !broadcast
      BMF::Alert.instance << "Unable to verify address #{to}..."
      init_compose
      haml :compose
    else
      res = "Sending message in background..."
      
      Thread.new do
        begin
          if broadcast
            res = BMF::XmlrpcClient.instance.sendBroadcast(from, subject, message)
            check_send res
          else

            to.split(";").each do |to_address|
              to_address = to_address.strip
              res = BMF::XmlrpcClient.instance.sendMessage(to_address, from, subject, message)
              check_send res
            end
          end

        rescue Exception => ex
          BMF::Alert.instance << "BACKGROUND SEND FAILED! #{ex.message}"
        end
      end
    
      confirm_message = "Sending in background..."
      if params[:goto] && params[:goto] != ""
        BMF::Alert.instance << confirm_message
        redirect params[:goto]
      else
        haml confirm_message
      end
    end
      
  end

  post "/messages/delete/", :provides => :html do
    msgid = params[:msgid]

    res = BMF::XmlrpcClient.instance.trashSentMessage(msgid)
    if BMF::XmlrpcClient.is_error? res
      halt(500, haml("Delete failed.  #{res}"))
    end
    
    res = BMF::XmlrpcClient.instance.trashMessage(msgid)
    if BMF::XmlrpcClient.is_error? res
      halt(500, haml("Delete failed.  #{res}"))
    end

    if request.referrer and request.referrer != ""
      cookies[:flash] = res
      redirect request.referrer
    else
      haml("#{res} [#{msgid}]")
    end

  end

  get "/subscriptions/", :provides => :html do

    @addresses = BMF::AddressStore.instance.subscriptions
    haml :subscriptions
  end
  
  post "/subscriptions/create/", :provides => :html do
    res = BMF::XmlrpcClient.instance.addSubscription params[:address], Base64.encode64(params[:label])
    
    if BMF::XmlrpcClient.is_error? res
      halt(500, haml("Error subscribing.  #{res}"))
    else
      haml("Subscribed.  #{res}")
    end
  end
  
  post "/subscriptions/delete/", :provides => :html do
    res = BMF::XmlrpcClient.instance.deleteSubscription params[:address]
    if BMF::XmlrpcClient.is_error? res
      halt(500, haml("Error deleting subscrition.  #{res}"))
    else
      haml("Subscription Deleted.  #{res}")
    end
  end
  
  post "/addressbook/create/", :provides => :html do
    res = BMF::XmlrpcClient.instance.addAddressBook params[:address], Base64.encode64(params[:label])
    
    if BMF::XmlrpcClient.is_error? res
      halt(500, haml("Error adding entry.  #{res}"))
    else
      haml("added Entry.  #{res}")
    end
  end
  
  post "/addressbook/delete/", :provides => :html do
    res = BMF::XmlrpcClient.instance.deleteAddressBook params[:address]
    if BMF::XmlrpcClient.is_error? res
      halt(500, haml("Error deleting address book entry.  #{res}"))
    else
      haml("Address Book Entry Deleted.  #{res}")
    end
  end
  

  get "/:folder/", :provides => :html do
    folder = BMF::Folder.new(params[:folder])
    @messages = folder.messages(:sort => :new)
    @addresses = BMF::AddressStore.instance.addresses
    haml :addresses
  end

  get "/:folder/:address/", :provides => :html do
    @addresses = BMF::AddressStore.instance.addresses
    folder = BMF::Folder.new(params[:folder])
    @address = params[:address]
    @threads = folder.threads_for_address(@address, :sort => :new)

    halt(404, haml("Couldn't find any threads matching #{params[:address]}.  Maybe you trashed them all.")) if @threads.nil?

    haml :threads
  end

  get "/:folder/:address/:thread", :provides => :html do
    @folder = BMF::Folder.new(params[:folder])
    
    @address = params[:address]

    @thread = CGI.unescape(params[:thread])
    @messages = @folder.thread_messages(@address, @thread, :sort => :old)

    halt(404, haml("Couldn't find any messages for thread #{params[:thread].inspect} for address #{params[:address].inspect}.  Maybe you trashed the messages.")) if @messages.nil?

    @addresses = BMF::AddressStore.instance.addresses

    # Get the last time we visited thread, and update to now
    @thread_last_visited = BMF::ThreadStatus.instance.thread_last_visited(@address,@thread)
    BMF::ThreadStatus.instance.thread_visited(@address, @thread, BMF::Message.time(@messages.last)) if @messages.last

    haml :messages
  end

  post "/:folder/thread/delete", :provides => :html do
    folder = BMF::Folder.new params[:folder]
    address = params[:address]
    thread = params[:thread]

    delete_statuses = folder.delete_thread(address, thread)

    if !delete_statuses.empty?
      delete_status_lines = delete_statuses.map { |x| "<li>#{x}</li>"}.join
      haml ("Deleted:<ol>#{delete_status_lines}</ol>")
    else
      halt(500, haml("No messages found for this thread!"))
    end
    
  end

  post "/:folder/thread/bulk_modify", :provides => :html do
    folder = BMF::Folder.new(params[:folder])
    address = params[:address]

    update_action = params[:update_action]
    threads_to_update = params.select { |key, value| key =~ /^thread__/}.values

    
    updates_list = threads_to_update[0..2].map{|t| "<li>#{CGI.escape_html(t)}</li>"}.join
    updates_list += "<li>(And #{threads_to_update[3..-1].length} more...)</li>" if !(threads_to_update[3..-1].nil? || threads_to_update[3..-1].empty?)
    updates_list = "<ul>" + updates_list + "</ul>"

    

    case update_action
    when "noop"
      status =  "Noop.  Did nothing to:"
    when "delete"
      status = "Background deleting the following threads:"

      Thread.new do
        address = params[:address]
        threads_to_update.each do |thread|
          folder.delete_thread(address, thread)
        end
      end
      
    when "mark_read"
      threads_to_update.each do |thread|
        BMF::ThreadStatus.instance.thread_visited(address, thread, Time.now.to_i)
      end
      
      status = "Marked the following threads as read."
    when "mark_all_read"

      folder.threads_for_address(address).each do |thread, thread_info|
        BMF::ThreadStatus.instance.thread_visited(address, thread, Time.now.to_i)
      end

      status = "Marked all threads as read."
    else
      raise "Unknown Action #{update_action}"
    end

    cookies[:flash] = "<div>#{status}#{updates_list}</div>"
    redirect "/#{folder.name}/#{address}/"
  end

  run! if app_file == $0

end

