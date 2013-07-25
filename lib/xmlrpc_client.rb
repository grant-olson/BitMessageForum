require 'singleton'
require 'xmlrpc/client'

class XmlrpcClientError < StandardError; end
class XmlrpcClient
  include Singleton

  def initialize
    @client = XMLRPC::Client.new2("http://kgo:kgo@localhost:8442/")
  end

  def method_missing meth, *args
    @client.call(meth.to_s, *args)
  end
  
end

