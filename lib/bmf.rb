require 'sinatra/base'
require 'sinatra/reloader'
require 'haml'
require_relative 'message_store.rb'
require_relative 'address_store.rb'
require_relative 'thread_status.rb'
require_relative 'message.rb'
require_relative 'settings.rb'

class BMF < Sinatra::Base

  set :server, 'thin'
  set :root, File.expand_path("../../", __FILE__)
  set :layout, :layout

  configure :development do
    register Sinatra::Reloader
  end

  def folder folder_name
    case folder_name
    when "chans"
      MessageStore.instance.chans
    when "inbox"
      MessageStore.instance.inbox
    when "sent"
      MessageStore.instance.sent
    when "lists"
      MessageStore.instance.lists
    else
      raise "BADFOLDER"
    end
  end

  

  def sync
    @new_messages = MessageStore.instance.update
    AddressStore.instance.update
  rescue Errno::ECONNREFUSED => ex
    @halt_message = "Couldn't connect to PyBitmessage server.  Is it running with the API enabled? " 
    halt(500, haml(:couldnt_reach_pybitmessage))
  rescue JSON::ParserError => ex
    @halt_message = "Couldn't sync.  It seems like PyBitmessage is running but refused access.  Do you have the correct info in config/settings.yml? "
    halt(500, haml(:couldnt_reach_pybitmessage))
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

    res = XmlrpcClient.instance.sendMessage(to, from, subject, message)
    if XmlrpcClient.is_error? res
      halt(500, haml(res))
    else
      haml "Sent.  Confirmation #{res}"
    end
  end

  post "/messages/delete/", :provides => :html do
    msgid = params[:msgid]
    res = XmlrpcClient.instance.trashMessage msgid
    if XmlrpcClient.is_error? res
      halt(500, haml("Delete failed.  #{res}"))
    else
      haml("#{res} [#{msgid}]")
    end
  end

  get "/:folder/", :provides => :html do
    sync

    @messages = folder params[:folder]
    @messages = @messages.sort { |a,b| MessageStore.instance.address_last_updates[a[0]] <=> MessageStore.instance.address_last_updates[b[0]] }.reverse
    @addresses = AddressStore.instance.addresses
    haml :addresses
  end

  get "/:folder/:address/", :provides => :html do
    sync
    
    @addresses = AddressStore.instance.addresses
    @address, @threads = folder(params[:folder]).detect {|address, threads| address == params[:address] }

    halt(404, haml("Couldn't find any threads matching #{params[:address]}.  Maybe you trashed them all.")) if @threads.nil?

    @threads = @threads.sort{ |a,b| MessageStore.instance.thread_last_updates[@address][a[0]] <=> MessageStore.instance.thread_last_updates[@address][b[0]] }.reverse
    haml :threads
    
  end

  get "/:folder/:address/:thread", :provides => :html do
    sync

    @folder = params[:folder]
    
    @address, threads = folder(@folder).detect {|address, threads| address == params[:address] }

    halt(404, haml("Couldn't find thread #{params[:thread].inspect} for address #{params[:address].inspect}.  Maybe you trashed the messages.")) if threads.nil?

    @thread, @messages = threads.detect do |thread, messages|
      # puts messages.inspect
      thread == CGI.unescape(params[:thread])
    end

    halt(404, haml("Couldn't find any messages for thread #{params[:thread].inspect} for address #{params[:address].inspect}.  Maybe you trashed the messages.")) if @messages.nil?

    @messages = @messages.sort {|a,b| Message.time(a) <=> Message.time(b)}
    
    @addresses = AddressStore.instance.addresses

    # Get the last time we visited thread, and update to now
    @thread_last_visited = ThreadStatus.instance.thread_last_visited(@address,@thread)
    ThreadStatus.instance.thread_visited(@address, @thread, Message.time(@messages.last))

    haml :messages
  end

  run! if app_file == $0

end

