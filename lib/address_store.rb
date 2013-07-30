require 'singleton'
require 'base64'
require 'json'
require 'thread'

require_relative 'xmlrpc_client.rb'

class AddressStore
  include Singleton

  attr_reader :addresses

  def initialize
    @addresses = {}
    # update
  end
  
  def log x
    puts x
  end

  def update
    address_infos = JSON.parse(XmlrpcClient.instance.listAddresses)['addresses']

    lock = Mutex.new

    lock.synchronize do
      address_infos.each do |address_info|
        address = address_info['address']
        if !@addresses.has_key? address
          @addresses[address] = address_info
          log "Added #{address}."
        end
      end
      
    end
  end
end
