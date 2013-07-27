class Folder
  VALID_FOLDERS = %w{chans inbox sent lists}

  attr_reader :name

  def initialize folder_name
    raise "Bad folder #{folder_name}" if !VALID_FOLDERS.include?(folder_name)
    @name = folder_name
    @messages = MessageStore.instance.send(folder_name)
  end

  def messages opts={}
    msgs = @messages
    
    if opts[:sort] == :new
      msgs = msgs.sort{ |a,b| MessageStore.instance.address_last_updates[a[0]] <=> MessageStore.instance.address_last_updates[b[0]] }.reverse
    end

    msgs
  end
  
  def threads_for_address address, opts={}
    threads = @messages[address]

    if threads && opts[:sort] == :new
      threads = threads.sort{ |a,b| MessageStore.instance.thread_last_updates[address][a[0]] <=> MessageStore.instance.thread_last_updates[address][b[0]] }.reverse
    end

    threads
  end
  
  def thread_messages address, thread_name, opts={}
    threads = threads_for_address(address)

    return nil if threads.nil?

    msgs = threads[thread_name]
    msgs = [] if msgs.nil?

    if opts[:sort] == :old
      msgs = msgs.sort { |a,b| Message.time(a) <=> Message.time(b) }
    end

    msgs
  end

  def delete_thread address, thread
    msgs = thread_messages(address, thread)
    return [] if msgs.nil?

    msgs.map{ |msg| msg['msgid']}.map{ |msgid| XmlrpcClient.instance.trashMessage(msgid) + msgid }
  end
  
end
