require 'sinatra/base'
require 'sinatra/reloader'
require 'sinatra/cookies'

require 'haml'

require_relative 'message_store.rb'
require_relative 'address_store.rb'
require_relative 'thread_status.rb'
require_relative 'message.rb'
require_relative 'settings.rb'
require_relative 'folder.rb'

require 'sanitize'

class BMF < Sinatra::Base
  helpers Sinatra::Cookies

  helpers do

    # If we've got some html, make it safe
    def safe_text text
      return text if !text.include?("<")


      if Settings.instance.display_sanitized_html != 'yes'
        CGI::escape_html(text)
      else
        local_images_only = Sanitize::Config::RELAXED.dup
        local_images_only[:protocols]["img"]["src"] = ["data"]

        Sanitize.clean(text.force_encoding("UTF-8"), local_images_only)
      end
      
    end
    
  end
  

  set :server, 'thin'
  set :root, File.expand_path("../../", __FILE__)
  set :layout, :layout

  settings = Settings.instance
  set :bind, settings.server_interface if settings.server_interface
  set :port, settings.server_port if settings.server_port

  configure :development do
    register Sinatra::Reloader
  end


  # 'sync' really updates new message count now that we're threaded
  def sync
    @@last_sync ||= 0

    @new_messages = MessageStore.instance.pop_new_message_count
    @new_messages = 0 if @@last_sync == 0

    @@last_sync = 1
  end




  get "/", :provides => :html do
    haml :home
  end

  def load_settings
    @settings = {}

    Settings::VALID_SETTINGS.each do |key|
      @settings[key] = Settings.instance.send(key)
    end
  end
  
  get "/identities/", :provides => :html do
    AddressStore.instance.update
    @addresses = AddressStore.instance.addresses

    haml :identities
  end

  post "/identities/new/", :provides => :html do
    if params[:label]
      label = Base64.encode64(params[:label])
      response = XmlrpcClient.instance.createRandomAddress label
      if XmlrpcClient.is_error? response
        halt(500, "Couldn't create address: #{response}")
      else
        haml("Created random address #{response} with label #{params[:label]}")
      end
    elsif params[:passphrase]
      passphrase = Base64.encode64(params[:passphrase])
      response = XmlrpcClient.instance.createDeterministicAddresses passphrase
      if XmlrpcClient.is_error? response
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
      Settings.instance.update(key,value)
    end
    Settings.instance.persist

    @flash = "Settings updated!"

    load_settings
    haml :settings
  end

  get "/messages/compose/", :provides => :html do
    sync #need address book if this is the first page we hit

    @to = params[:to]
    @from = params[:from]
    @subject = params[:subject]

    if (@from.nil? || @from == "") && Settings.instance.default_send_address
      @from = Settings.instance.default_send_address
    end
    
    if params[:reply_to]
      @message = "&nbsp\n------------------------------------------------------\n" + MessageStore.instance.messages[params[:reply_to]]['message']
    else
      @message = params[:message]
    end
    
    @message = "" if @message.nil?
    if Settings.instance.sig
      @message = "&nbsp;\n" + Settings.instance.sig + "\n" + @message
    end

    haml :compose
  end

  post "/messages/send/", :provides => :html do
    to = params[:to]
    from = params[:from]
    subject = Base64.encode64(params[:subject])
    message = Base64.encode64(params[:message])
    broadcast = params[:broadcast]


    res = "Sending message in background..."

    Thread.new do
      puts "Starting background send of message..."
      if broadcast
        res = XmlrpcClient.instance.sendBroadcast(from, subject, message)
      else
        res = XmlrpcClient.instance.sendMessage(to, from, subject, message)
      end

      if XmlrpcClient.is_error? res
        puts "BACKGROUND SEND FAILED! #{res}"
      else
        puts "Background send seemed to finish successfully"
      end
    end
    
    confirm_message = "Sending in background..."
    if params[:goto] && params[:goto] != ""
      cookies[:flash] = confirm_message
      redirect params[:goto]
    else
      haml confirm_message
    end
      
  end

  post "/messages/delete/", :provides => :html do
    msgid = params[:msgid]
    res = XmlrpcClient.instance.trashMessage msgid
    if XmlrpcClient.is_error? res
      halt(500, haml("Delete failed.  #{res}"))
    else
      if request.referrer and request.referrer != ""
        cookies[:flash] = res
        redirect request.referrer
      else
        haml("#{res} [#{msgid}]")
      end
    end
  end

  get "/subscriptions/", :provides => :html do
    haml :subscriptions
  end
  
  post "/subscriptions/create/", :provides => :html do
    res = XmlrpcClient.instance.addSubscription params[:address], Base64.encode64(params[:label])
    if XmlrpcClient.is_error? res
      halt(500, haml("Error subscribing.  #{res}"))
    else
      haml("Subscribed.  #{res}")
    end
  end
  
  post "/subscriptions/delete/", :provides => :html do
    res = XmlrpcClient.instance.deleteSubscription params[:address]
    if XmlrpcClient.is_error? res
      halt(500, haml("Error deleting subscrition.  #{res}"))
    else
      haml("Subscription Deleted.  #{res}")
    end
  end
  

  get "/:folder/", :provides => :html do
    sync

    folder = Folder.new(params[:folder])
    @messages = folder.messages(:sort => :new)
    @addresses = AddressStore.instance.addresses
    haml :addresses
  end

  get "/:folder/:address/", :provides => :html do
    sync
    
    @addresses = AddressStore.instance.addresses
    folder = Folder.new(params[:folder])
    @address = params[:address]
    @threads = folder.threads_for_address(@address, :sort => :new)

    halt(404, haml("Couldn't find any threads matching #{params[:address]}.  Maybe you trashed them all.")) if @threads.nil?

    haml :threads
  end

  get "/:folder/:address/:thread", :provides => :html do
    sync

    @folder = Folder.new(params[:folder])
    
    @address = params[:address]

    @thread = CGI.unescape(params[:thread])
    @messages = @folder.thread_messages(@address, @thread, :sort => :old)

    halt(404, haml("Couldn't find any messages for thread #{params[:thread].inspect} for address #{params[:address].inspect}.  Maybe you trashed the messages.")) if @messages.nil?

    @addresses = AddressStore.instance.addresses

    # Get the last time we visited thread, and update to now
    @thread_last_visited = ThreadStatus.instance.thread_last_visited(@address,@thread)
    ThreadStatus.instance.thread_visited(@address, @thread, Message.time(@messages.last)) if @messages.last

    haml :messages
  end

  post "/:folder/thread/delete", :provides => :html do
    folder = Folder.new params[:folder]
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
    folder = Folder.new(params[:folder])
    address = params[:address]

    update_action = params[:update_action]
    threads_to_update = params.select { |key, value| key =~ /^thread__/}.values

    updates_list = threads_to_update.map{|t| "<li>#{CGI.escape_html(t)}</li>"}.join
    updates_list = "<ul>" + updates_list + "</ul>"

    case update_action
    when "noop"
      status =  "Noop.  Did nothing to:"
    when "delete"
      address = params[:address]
      threads_to_update.each do |thread|
        folder.delete_thread(address, thread)
      end
      
      status = "Deleted the following threads:"
    when "mark_read"
      threads_to_update.each do |thread|
        ThreadStatus.instance.thread_visited(address, thread, Time.now.to_i)
      end
      
      status = "Marked the following threads as read."
    when "mark_all_read"

      folder.threads_for_address(address).each do |thread, thread_info|
        ThreadStatus.instance.thread_visited(address, thread, Time.now.to_i)
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

