module Message
  def self.time(m)
    time = m['receivedTime']
    time = m['lastActionTime'] if time.nil?
    time.to_i
  end
  
end
