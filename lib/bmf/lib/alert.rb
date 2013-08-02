require 'singleton'
require 'thread'

class BMF::Alert
  include Singleton

  def initialize
    @alerts = []
    @new_messages = 0
  end

  def << alert
    Mutex.new.synchronize do
      if !@alerts.include? alert
        @alerts << alert
      end
    end
  end

  def peek
    Mutex.new.synchronize do
      @alerts.dup.freeze
    end
  end

  def pop
    Mutex.new.synchronize do
      alerts = @alerts.dup.freeze
      @alerts = []
      alerts
    end
  end

  def add_new_messages i
    Mutex.new.synchronize do
      @new_messages += i
    end
  end

  def peek_new_messages
    Mutex.new.synchronize do
      @new_messages
    end
  end

  def pop_new_messages
    Mutex.new.synchronize do
      i = @new_messages
      @new_messages = 0
      i
    end
  end
end
