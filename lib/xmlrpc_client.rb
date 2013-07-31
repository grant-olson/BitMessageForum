require 'singleton'
require 'xmlrpc/client'
require_relative 'settings.rb'

class XmlrpcClientError < StandardError; end
class XmlrpcClient
  include Singleton

  def initialize
    initialize_client
  end

  def initialize_client
    @client = XMLRPC::Client.new2(Settings.instance.server_url)
  end

  def method_missing meth, *args
    @client.call(meth.to_s, *args)
  end

  def self.is_error? response_string
    return true if response_string =~ /^Invalid Method:/
    response_string =~ /^API Error /
  end
end

