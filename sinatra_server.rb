require 'sinatra'
require 'haml'
require_relative 'message_store.rb'
require_relative 'address_store.rb'

$message_store = MessageStore.new
$address_store = AddressStore.new

def folder folder_name
  case folder_name
  when "chans"
    $message_store.chans
  when "inbox"
    $message_store.inbox
  when "lists"
    $message_store.lists
  else
    raise "BADFOLDER"
  end
end


get "/", :provides => :html do
  $message_store.update
  @messages = folder("inbox")
  @addresses = $address_store.addresses
  haml :threaded_messages, :layout => :layout
end

get "/:folder/", :provides => :html do
  $message_store.update
  @messages = folder params[:folder]
  
  @addresses = $address_store.addresses
  haml :addresses, :layout => :layout
end

get "/:folder/:address/", :provides => :html do
  $message_store.update
  
  @address, @threads = folder(params[:folder]).detect {|address, threads| address == params[:address] }
  @addresses = $address_store.addresses

  haml :threads, :layout => :layout
  
end

get "/:folder/:address/:thread", :provides => :html do
  $message_store.update
  
  @address, threads = folder(params[:folder]).detect {|address, threads| address == params[:address] }
  @thread, @messages = threads.detect do |thread, messages|
    # puts messages.inspect
    thread == CGI.unescape(params[:thread])
  end
  
  
  @addresses = $address_store.addresses

  haml :messages, :layout => :layout
  
end

