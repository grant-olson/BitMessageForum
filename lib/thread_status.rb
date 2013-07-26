require 'singleton'
require_relative 'message_store.rb'

class ThreadStatus
  include Singleton

  def initialize
    @thread_last_visited = {}
  end
  
  def thread_visited(address, thread, time)
    @thread_last_visited[address] ||= {}
    @thread_last_visited[address][thread] ||= 0

    if time > @thread_last_visited[address][thread]
      @thread_last_visited[address][thread] = time
    end
  end

  def new_messages?(address, thread)
    puts address.inspect
    puts thread.inspect

    if @thread_last_visited[address] && @thread_last_visited[address][thread]
      last_visited_time = @thread_last_visited[address][thread]
    else
      last_visited_time = 0
    end
    
    last_message_time = MessageStore.instance.thread_last_updates[address][thread]

    last_visited_time < last_message_time
  end
  
  
end
