require 'sinatra'
require 'haml'
require_relative 'message_store.rb'
require_relative 'address_store.rb'

$message_store = MessageStore.new
$address_store = AddressStore.new

get "/", :provides => :html do
  $message_store.update
  @messages = $message_store.inbox
  @addresses = $address_store.addresses
  haml :threaded_messages, :layout => :layout
end

get "/inbox", :provides => :html do
  $message_store.update
  @messages = $message_store.inbox
  @addresses = $address_store.addresses
  haml :threaded_messages, :layout => :layout
end

get "/lists", :provides => :html do
  $message_store.update
  @messages = $message_store.lists
  @addresses = $address_store.addresses
  haml :threaded_messages, :layout => :layout
end

get "/chans", :provides => :html do
  $message_store.update
  @messages = $message_store.chans
  @addresses = $address_store.addresses
  haml :threaded_messages, :layout => :layout
end

