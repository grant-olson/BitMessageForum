require_relative "message_store.rb"
require_relative "thread_status.rb"

class BMF::Folder
  VALID_FOLDERS = %w{chans inbox sent lists}

  attr_reader :name

  def initialize folder_name
    raise "Bad folder #{folder_name}" if !VALID_FOLDERS.include?(folder_name)
    @name = folder_name
    @messages = BMF::MessageStore.instance.send(folder_name)
  end

  def new_messages?
    @messages.each_pair do |address, threads|
      return true if BMF::ThreadStatus.instance.new_messages_for_address?(address, threads.keys)
    end

    return false
  end
  
  def messages opts={}
    msgs = @messages
    
    if opts[:sort] == :new
      msgs = msgs.sort{ |a,b| BMF::MessageStore.instance.address_last_updates[a[0]] <=> BMF::MessageStore.instance.address_last_updates[b[0]] }.reverse
    end

    msgs
  end
  
  def threads_for_address address, opts={}
    threads = @messages[address]

    if threads && opts[:sort] == :new
      threads = threads.sort{ |a,b| BMF::MessageStore.instance.thread_last_updates[address][a[0]] <=> BMF::MessageStore.instance.thread_last_updates[address][b[0]] }.reverse
    end

    threads
  end
  
  def thread_messages address, thread_name, opts={}
    threads = threads_for_address(address)

    return nil if threads.nil?

    msgs = threads[thread_name]
    msgs = [] if msgs.nil?

    if opts[:sort] == :old
      msgs = msgs.sort { |a,b| BMF::Message.time(a) <=> BMF::Message.time(b) }
    end

    msgs
  end

  def delete_thread address, thread
    msgs = thread_messages(address, thread)
    return [] if msgs.nil?
   
    alerts = []

    msgs.each do |msg|
      msgid = msg['msgid']
      if msg['_source'] == 'sent'
        alerts << (BMF::XmlrpcClient.instance.trashSentMessage(msgid) + msgid)
      else
        alerts << (BMF::XmlrpcClient.instance.trashMessage(msgid) + msgid)
      end
    end
    
    alerts
  end
  
end
