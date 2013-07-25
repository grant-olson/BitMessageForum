require_relative 'xmlrpc_client.rb'
require 'base64'

class AddressStore
  attr_reader :addresses

  def initialize
    @client = XmlrpcClient.new
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
