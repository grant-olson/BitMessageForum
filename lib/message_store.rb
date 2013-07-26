require 'singleton'
require 'base64'
require 'json'
require_relative 'xmlrpc_client.rb'

class MessageStore
  include Singleton

  attr_reader :messages, :address_last_updates, :thread_last_updates

  def initialize
    @messages = {} # messages by msgid
    @address_last_updates = {}
    @thread_last_updates = {}
    # update
  end
  
  def log x
    puts x
  end
    
  def process_messages new_messages, source="inbox"
    new_messages.each do |m|
      msgid = m["msgid"]

      if !@messages.has_key?(msgid)
        m["message"] = Base64.decode64(m["message"])
        m["subject"] = Base64.decode64(m["subject"])
        m["_source"] = source
        messages[msgid] = m

        to_address = m["toAddress"]

        # Temp hack for lists
        if to_address == "[Broadcast subscribers]"
          hack_mailing_list_name =  m["subject"][/\[.*\]/]
          to_address += " " + hack_mailing_list_name
          m["toAddress"] = to_address
        end

        received_time = m["receivedTime"].to_i

        # update channel access time
        address_last_updates[to_address] ||= 0
        if address_last_updates[to_address] < received_time
          address_last_updates[to_address] = received_time
        end

        subject = m["subject"]
        if subject[0..3] == "Re: "
          subject = subject[4..-1]
        end
        
        # update thread access time
        thread_last_updates[to_address] ||= {}
        thread_last_updates[to_address][subject] ||= 0
        
        if thread_last_updates[to_address][subject] < received_time
          thread_last_updates[to_address][subject] = received_time
        end

        log "Added new message #{msgid}."
      end
    end

  end

  def update
    inbox_messages = JSON.parse(XmlrpcClient.instance.getAllInboxMessages)
    process_messages inbox_messages['inboxMessages']

    sent_messages = JSON.parse(XmlrpcClient.instance.getAllSentMessages)
    process_messages sent_messages['sentMessages'], "sent"
  end
  
  def by_recipient
 
    #display messages

    by_recipient = {}

    messages.each do |id, m|
      toAddress = m["toAddress"]

      subject = m["subject"]
      if subject[0..3] == "Re: "
        subject = subject[4..-1]
      end
      
      by_recipient[toAddress] = {} if !by_recipient[toAddress]
      by_recipient[toAddress][subject] = [] if !by_recipient[toAddress][subject]
      by_recipient[m["toAddress"]][subject] << m
    end

    by_recipient
  end

  def inbox
    by_recipient.select do |toAddress, messages|
      label = if AddressStore.instance.addresses.has_key? toAddress
                AddressStore.instance.addresses[toAddress]['label']
              else
                ""
              end
      not( label.include?("[chan]") || toAddress.include?("[Broadcast subscribers]"))
    end
  end

  def lists
    by_recipient.select do |toAddress, messages|
      toAddress.include? "[Broadcast subscribers]"
    end
  end

  def chans
    by_recipient.select do |toAddress, messages|
      label = if AddressStore.instance.addresses.has_key? toAddress
                AddressStore.instance.addresses[toAddress]['label']
              else
                ""
              end
      label.include?("[chan]")
    end
  end
  

end
