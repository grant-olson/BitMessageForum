require 'sinatra'
require 'haml'
require_relative 'message_store.rb'

$message_store = MessageStore.new

get "/", :provides => :html do
  $message_store.update
  @messages = $message_store.by_recipient
  haml :threaded_messages, :layout => :layout
end
