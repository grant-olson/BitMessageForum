require 'singleton'
require 'base64'
require_relative 'message_store.rb'

class BMF::ThreadStatus
  include Singleton

  STASH_FILE = File.expand_path("../../../../config/thread_status_stash", __FILE__)

  def load_stash
    if File.exists? STASH_FILE
      stash = File.open(STASH_FILE).read
      stash.split(";").each do |stash_line|
        address, thread, update_time = stash_line.split(':')
        thread = Base64.decode64(thread.gsub("\\n","\n"))
        update_time = update_time.to_i
        thread_visited(address,thread,update_time)
      end
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
  
  def initialize
    @thread_last_visited = {}
    load_stash
  end

  def persist
    updates = []
    @thread_last_visited.each_pair do |address, threads|
      threads.each_pair do |thread_name, update_time|
        updates << "#{address}:#{Base64.encode64(thread_name).gsub("\n","\\n")}:#{update_time}"
      end
    end
    
    stash = updates.join(";")

    File.open(STASH_FILE,"w") do |f|
      f.write(stash)
    end
  end
  

  def thread_last_visited(address, thread)
    if @thread_last_visited[address] && @thread_last_visited[address][thread]
      @thread_last_visited[address][thread]
    else
      0
    end
  end
  
  def thread_visited(address, thread, time)
    @thread_last_visited[address] ||= {}
    @thread_last_visited[address][thread] ||= 0

    if time > @thread_last_visited[address][thread]
      @thread_last_visited[address][thread] = time
    end

    persist
  end

  def new_messages?(address, thread)
    if @thread_last_visited[address] && @thread_last_visited[address][thread]
      last_visited_time = @thread_last_visited[address][thread]
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
