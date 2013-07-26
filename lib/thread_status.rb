require 'singleton'
require_relative 'message_store.rb'

class ThreadStatus
  include Singleton

  def initialize
    @thread_last_visited = {}
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
  end

  def new_messages?(address, thread)
    if @thread_last_visited[address] && @thread_last_visited[address][thread]
      last_visited_time = @thread_last_visited[address][thread]
    else
      last_visited_time = 0
    end
    
    last_message_time = MessageStore.instance.thread_last_updates[address][thread]

    raise thread.inspect if last_message_time.nil?

    last_visited_time < last_message_time
  end

  def new_messages_for_address?(address, threads)
    return true if !@thread_last_visited[address] # never been updated

    not threads.detect{ |thread| new_messages?(address, thread)}.nil?

  end
  
end
