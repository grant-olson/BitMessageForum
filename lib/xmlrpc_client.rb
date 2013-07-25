require 'singleton'
require 'xmlrpc/client'
require 'json'

class XmlrpcClientError < StandardError; end
class XmlrpcClient
  include Singleton

  def initialize
    @client = XMLRPC::Client.new2("http://kgo:kgo@localhost:8442/")
  end

  def method_missing meth, *args
    JSON.parse @client.call(meth.to_s, *args)
  rescue JSON::ParserError => ex
    raise XmlrpcClientError, ex.message
  end
  
end

