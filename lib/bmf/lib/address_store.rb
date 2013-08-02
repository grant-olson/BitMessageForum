require 'singleton'
require 'base64'
require 'json'
require 'thread'

require_relative 'xmlrpc_client.rb'

class BMF::AddressStore
  include Singleton

#  attr_reader :addresses

  def addresses
    Mutex.new.synchronize { @addresses.dup.freeze }
  end

  def initialize
    @addresses = {}
    # update
  end
  
  def log x
    puts x
  end

  def update
    address_infos = JSON.parse(BMF::XmlrpcClient.instance.listAddresses)['addresses']

    lock = Mutex.new

    lock.synchronize do
      new_addresses = 0

      address_infos.each do |address_info|
        address = address_info['address']
        if !@addresses.has_key? address
          new_addresses += 1
          @addresses[address] = address_info
        end
      end

      log "Added #{new_addresses} addresses..." if new_addresses > 0
    end
  end
end
