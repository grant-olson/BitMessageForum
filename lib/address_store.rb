require 'singleton'
require 'base64'
require_relative 'xmlrpc_client.rb'

class AddressStore
  include Singleton

  attr_reader :addresses

  def initialize
    @client = XmlrpcClient.instance
    @addresses = {}
    # update
  end
  
  def log x
    puts x
  end

  def update
    address_infos = @client.listAddresses['addresses']
    address_infos.each do |address_info|
      address = address_info['address']
      if !@addresses.has_key? address
        @addresses[address] = address_info
        log "Added #{address}."
      end
    end
  end
end
