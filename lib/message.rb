module Message
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
  
end
