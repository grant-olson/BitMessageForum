require 'xmlrpc/client'

class XmlrpcClient
  def initialize
    @client = XMLRPC::Client.new2("http://kgo:kgo@localhost:8442/")
  end

  def method_missing meth, *args
    @client.call(meth.to_s, *args)
  end
  
end

