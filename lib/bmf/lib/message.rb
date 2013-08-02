module BMF::Message
  def self.time(m)
    time = m['receivedTime']
    time = m['lastActionTime'] if time.nil?
    time.to_i
  end

  def self.sent?(m)
    !m['lastActionTime'].nil?
  end

  def self.received?(m)
    !m['receivedTime'].nil?
  end
  
  def self.sent_or_received m
    if sent?(m)
      :sent
    elsif received?(m)
      :received
    else
      raise "Don't know if #{m.inspect} was sent or received"
    end
  end
  

end
