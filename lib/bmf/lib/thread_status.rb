require 'singleton'
require_relative 'message_store.rb'
require_relative 'settings.rb'
require 'digest/sha2'

class BMF::ThreadStatus
  include Singleton

  STASH_FILE = BMF::Settings.fully_qualified_filename("thread_status_stash")

  def initialize
    @thread_last_visited = {}
    load_stash
  end

  def hash_thread thread
    Digest::SHA256.new.update(Digest::SHA256.new.update(thread).to_s).to_s
  end

  def serialize_stash
    updates = []
    @thread_last_visited.each_pair do |address, threads|
      threads.each_pair do |thread_name, update_time|
        updates << "#{address}:#{thread_name}:#{update_time}"
      end
    end
    
    updates.join(";")
  end
  
  def deserialize_stash serialized_stash
    serialized_stash.split(";").each do |stash_line|
      address, thread, update_time = stash_line.split(':')
      next if thread.length != 64 # old unhashed format
      update_time = update_time.to_i
      hashed_thread_visited(address,thread,update_time)
    end
  end

  def load_stash
    if File.exists? STASH_FILE
      stash = File.open(STASH_FILE).read
      deserialize_stash stash
    else
      puts "No thread stash file.  Must be a new install.  Marking all threads as read..."
      BMF::MessageStore.instance.thread_last_updates.each_pair do |address, threads|
        threads.each_pair do |thread, time|
          thread_visited(address,thread,time,:persist => false)
        end
        
      end
      persist
    end
  rescue Exception => ex # Failure is not an option!
    puts "@" * 80
    puts "Error loading ThreadStatus stash."
    puts "Ignoring so that the app is usable."
    puts "Please report the following information to the project maintainers"
    puts
    puts "Exception: #{ex.message}"
    puts ex.backtrace.join("\n")
  end
  
  def persist
    File.open(STASH_FILE,"w",0600) do |f|
      f.write(serialize_stash)
    end
  end
  

  def thread_last_visited(address, thread)
    thread = hash_thread(thread)
    if @thread_last_visited[address] && @thread_last_visited[address][thread]
      @thread_last_visited[address][thread]
    else
      0
    end
  end
  
  def hashed_thread_visited(address, thread, time)
    @thread_last_visited[address] ||= {}
    @thread_last_visited[address][thread] ||= 0

    if time > @thread_last_visited[address][thread]
      @thread_last_visited[address][thread] = time
    end

  end
  

  def thread_visited(address, thread, time, opts={})
    opts[:persist] = true if opts[:persist].nil?
    
    thread = hash_thread(thread)
    hashed_thread_visited(address, thread, time)
    
    persist if opts[:persist]
  end

  def new_messages?(address, thread)
    hashed_thread = hash_thread(thread)

    if @thread_last_visited[address] && @thread_last_visited[address][hashed_thread]
      last_visited_time = @thread_last_visited[address][hashed_thread]
    else
      last_visited_time = 0
    end
    
    last_message_time = BMF::MessageStore.instance.thread_last_updates[address][thread]

    raise thread.inspect if last_message_time.nil?

    last_visited_time < last_message_time
  end

  def new_messages_for_address?(address, threads)
    return true if !@thread_last_visited[address] # never been updated

    not threads.detect{ |thread| new_messages?(address, thread)}.nil?

  end
  
end
