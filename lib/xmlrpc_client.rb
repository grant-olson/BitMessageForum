require 'singleton'
require 'xmlrpc/client'
require 'yaml'

class XmlrpcClientError < StandardError; end
class XmlrpcClient
  include Singleton

  def initialize
    settings = YAML.load_file(File.expand_path("../../config/settings.yml", __FILE__))['server_url']
    @client = XMLRPC::Client.new2(settings)
  end

  def method_missing meth, *args
    @client.call(meth.to_s, *args)
  end

  def self.is_error? response_string
    response_string =~ /^API Error /
  end
end

