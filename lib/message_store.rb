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
    
  def update_times m
    received_time = Message.time(m)
    to_address = m["toAddress"]

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
  end

  def add_message msgid, m
    m["message"] = Base64.decode64(m["message"])
    m["subject"] = Base64.decode64(m["subject"])

    m["subject"] = " " if m["subject"] == ""
    messages[msgid] = m

    to_address = m["toAddress"]

    # Temp hack for lists
    if to_address == "[Broadcast subscribers]"
      hack_mailing_list_name =  m["subject"][/\[[^\]]+\]/]
      
      hack_mailing_list_name = m["fromAddress"] if hack_mailing_list_name.nil?

      to_address += " " + hack_mailing_list_name
      m["toAddress"] = to_address
    end


    log "Added new message #{msgid}."
  end

  def process_messages new_messages, source="inbox"
    processed_messages = 0

    new_messages.each do |m|
      msgid = m["msgid"]

      @new_msgids[msgid] = true

      if !@messages.has_key?(msgid)
        processed_messages += 1
        m["_source"] = source
        add_message msgid, m
        update_times m
      end
    end

    processed_messages
  end

  def init_gc
    @new_msgids = {}
  end

  def do_gc
    messages.keys.each do |old_msgid|
      if !@new_msgids[old_msgid]
        messages.delete(old_msgid)
        log "Deleted message #{old_msgid}."
      end
    end
  end

  def update
    init_gc

    inbox_messages = JSON.parse(XmlrpcClient.instance.getAllInboxMessages)
    new_messages = process_messages(inbox_messages['inboxMessages'])

    sent_messages = JSON.parse(XmlrpcClient.instance.getAllSentMessages)
    process_messages(sent_messages['sentMessages'], "sent")

    do_gc

    new_messages
  end
  
  def by_recipient sent_or_received=:nil
 
    #display messages

    by_recipient = {}

    messages.each do |id, m|
      if sent_or_received
        next if sent_or_received == :sent && !Message.sent?(m)
        next if sent_or_received == :received && !Message.received?(m)
      end
      
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
    by_recipient(:received).select do |toAddress, messages|
      label = if AddressStore.instance.addresses.has_key? toAddress
                AddressStore.instance.addresses[toAddress]['label']
              else
                ""
              end
      not( label.include?("[chan]") || toAddress.include?("[Broadcast subscribers]"))
    end
  end

  def sent
    by_recipient(:sent).select do |toAddress, messages|
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
