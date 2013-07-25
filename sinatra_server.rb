require 'sinatra'
require 'haml'
require_relative 'message_store.rb'
require_relative 'address_store.rb'

$message_store = MessageStore.new
$address_store = AddressStore.new

get "/", :provides => :html do
  $message_store.update
  @messages = $message_store.by_recipient
  @addresses = $address_store.addresses
  haml :threaded_messages, :layout => :layout
end
