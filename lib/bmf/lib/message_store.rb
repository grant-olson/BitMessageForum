require 'singleton'
require 'base64'
require 'json'
require 'thread'

require_relative 'xmlrpc_client.rb'

class BMF::MessageStore
  include Singleton

  

  def initialize
    @messages = {} # messages by msgid
    @address_last_updates = {}
    @thread_last_updates = {}
    @new_messages = 0
    # update
  end
  
  def log x
    puts x
  end

#  attr_reader :messages, :address_last_updates, :thread_last_updates

  def messages
    Mutex.new.synchronize { @messages.dup.freeze }
  end
  
  def address_last_updates
    Mutex.new.synchronize { @address_last_updates.dup.freeze }
  end

  def thread_last_updates
    Mutex.new.synchronize { @thread_last_updates.dup.freeze }
  end
    
  def strip_RE subject
    while ["Re: ", "RE: "].include?(subject[0..3])
      subject = subject[4..-1]
    end
    subject = " " if subject == ""
    subject
  end
                                     

  def update_times m
    received_time = BMF::Message.time(m)
    to_address = m["toAddress"]

    # update channel access time
    @address_last_updates[to_address] ||= 0
    if @address_last_updates[to_address] < received_time
      @address_last_updates[to_address] = received_time
    end

    subject = strip_RE(m["subject"])
    
    # update thread access time
    @thread_last_updates[to_address] ||= {}
    @thread_last_updates[to_address][subject] ||= 0
    
    if @thread_last_updates[to_address][subject] < received_time
      @thread_last_updates[to_address][subject] = received_time
    end
  end

  def add_message msgid,m
    m["message"] = Base64.decode64(m["message"]).force_encoding("utf-8")
    m["subject"] = Base64.decode64(m["subject"]).force_encoding("utf-8")

    m["subject"] = " " if m["subject"] == ""
    m["subject"] = "Re:  " if m["subject"] == "Re: "

    @messages[msgid] = m

    to_address = m["toAddress"]

    # Temp hack for lists
    if to_address == "[Broadcast subscribers]"
      hack_mailing_list_name =  m["subject"][/\[[^\]]+\]/]
      
      hack_mailing_list_name = m["fromAddress"] if hack_mailing_list_name.nil?

      to_address += " " + hack_mailing_list_name
      m["toAddress"] = to_address
    end
  end

  def get_full_message mailbox, msgid
    msg_json = BMF::XmlrpcClient.instance.send("get#{mailbox.capitalize}MessageByID", msgid)
    JSON.parse(msg_json)["#{mailbox}Message"][0]
  end
  

  def process_messages new_messages, source="inbox"
    processed_messages = 0

    new_messages.each do |m|
      msgid = m["msgid"]

      @new_msgids[msgid] = true

      if !@messages.has_key?(msgid)
        processed_messages += 1

        if m["message"] # cliend doesn't support getXMessageIds, so we already have everything
          full_message = m
        else
          full_message = get_full_message(source, msgid)
        end
        

        full_message["_source"] = source

        add_message msgid, full_message

        update_times full_message
      end
    end

    log "Added #{processed_messages} messages..." if processed_messages > 0

    processed_messages
  end

  def init_gc
    @new_msgids = {}
  end

  def do_gc
    deleted_messages = 0
    @messages.keys.each do |old_msgid|
      if !@new_msgids[old_msgid]
        deleted_messages += 1
        @messages.delete(old_msgid)
      end
    end

    log "Deleted #{deleted_messages}..." if deleted_messages > 0
  end

  def get_all_message_ids mailbox
    method = "getAll#{mailbox.capitalize}MessageIds"
    msgids = BMF::XmlrpcClient.instance.send(method)
    if BMF::XmlrpcClient.is_error?(msgids) && msgids.downcase.include?("invalid method")
      log "PyBitmessage doesn't support #{method}.  Falling back to getAll#{mailbox.capitalize}Messages.  Using a version of Pybitmessage that supports #{method} will dramatically increase performance"
      msgids = BMF::XmlrpcClient.instance.send("getAll#{mailbox.capitalize}Messages")
      JSON.parse(msgids)["#{mailbox}Messages"]
    else
      JSON.parse(msgids)["#{mailbox}MessageIds"]
    end
  end
  

  def update

    inbox_messages = get_all_message_ids "inbox"
    sent_messages = get_all_message_ids "sent"
    
    new_messages = 0

    lock = Mutex.new
    lock.synchronize do
      init_gc

      new_messages += process_messages(inbox_messages)
      process_messages(sent_messages, "sent")

      do_gc
    end

    new_messages
  end
  
  def pop_new_message_count
    new = 0

    Mutex.new.synchronize do
      new += @new_messages
      @new_messages = 0
    end

    new
  end
  

  def by_recipient sent_or_received=:nil
 
    #display messages

    by_recipient = {}

    @messages.each do |id, m|
      if sent_or_received
        next if sent_or_received == :sent && !BMF::Message.sent?(m)
        next if sent_or_received == :received && !BMF::Message.received?(m)
      end
      
      toAddress = m["toAddress"]

      subject = strip_RE(m["subject"])
      
      by_recipient[toAddress] = {} if !by_recipient[toAddress]
      by_recipient[toAddress][subject] = [] if !by_recipient[toAddress][subject]
      by_recipient[m["toAddress"]][subject] << m
    end

    by_recipient
  end

  def inbox
    by_recipient(:received).select do |toAddress, messages|
      label = if BMF::AddressStore.instance.addresses.has_key? toAddress
                BMF::AddressStore.instance.addresses[toAddress]['label']
              else
                ""
              end
      not( label.include?("[chan]") || toAddress.include?("[Broadcast subscribers]"))
    end
  end

  def sent
    by_recipient(:sent).select do |toAddress, messages|
      label = if BMF::AddressStore.instance.addresses.has_key? toAddress
                BMF::AddressStore.instance.addresses[toAddress]['label']
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
      label = if BMF::AddressStore.instance.addresses.has_key? toAddress
                BMF::AddressStore.instance.addresses[toAddress]['label']
              else
                ""
              end
      label.include?("[chan]")
    end
  end
  

end
