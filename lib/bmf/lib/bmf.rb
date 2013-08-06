require 'sinatra/base'
require 'sinatra/reloader'
require 'sinatra/cookies'

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
      if !text.include?("<") && !starts_with_markdown
        return "<blockquote>" + text.gsub("\n","<br />\n") + "</blockquote>"
      end

      if BMF::Settings.instance.display_sanitized_html != 'yes'
        return "<blockquote>" + CGI::escape_html(text).gsub("\n", "<br />\n")  + "</blockqoute>"
      end

      if text.strip.start_with? markdown_content_type
        text = RDiscount.new(text.sub(markdown_content_type, "")).to_html
      end

      safe_html(text)
      
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

  get "/json/new_messages/", :provides => :json do
    {:new_messages => BMF::Alert.instance.peek_new_messages}.to_json
  end
  
  get "/identities/", :provides => :html do
    BMF::AddressStore.instance.update
    @addresses = BMF::AddressStore.instance.addresses

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

  get "/messages/compose/", :provides => :html do
    @to = params[:to]
    @from = params[:from]
    @subject = params[:subject]

    if (@from.nil? || @from == "") && BMF::Settings.instance.default_send_address
      @from = BMF::Settings.instance.default_send_address
    end
    
    if params[:reply_to]
      @message = "&nbsp\n------------------------------------------------------\n" + BMF::MessageStore.instance.messages[params[:reply_to]]['message']
    else
      @message = params[:message]
    end
    
    @message = "" if @message.nil?
    if BMF::Settings.instance.sig
      @message = "&nbsp;\n" + BMF::Settings.instance.sig + "\n" + @message
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
      begin
        if broadcast
          res = BMF::XmlrpcClient.instance.sendBroadcast(from, subject, message)
        else
          res = BMF::XmlrpcClient.instance.sendMessage(to, from, subject, message)
        end

        if BMF::XmlrpcClient.is_error? res
          BMF::Alert.instance << "BACKGROUND SEND FAILED! #{res}"
        else
          BMF::Alert.instance << "Background send seemed to finish successfully"
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

    res = BMF::XmlrpcClient.instance.listSubscriptions

    if BMF::XmlrpcClient.is_error? res
      @subscriptions = []
    else
      @subscriptions = JSON.parse(res)['subscriptions']
    end
    
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

