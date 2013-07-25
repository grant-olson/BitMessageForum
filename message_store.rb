require_relative 'xmlrpc_client.rb'
require 'json'
require 'base64'

class MessageStore

  attr_reader :messages

  def initialize
    @client = XmlrpcClient.new
    @messages = {} # messages by msgid
    update
  end
  
  def log x
    puts x
  end
    
  def update
    inbox_messages = JSON.parse @client.getAllInboxMessages
    inbox = inbox_messages['inboxMessages']

    # fix messages
    inbox.each do |m|
      msgid = m["msgid"]

      if @messages.has_key? msgid
        log "Already saw #{msgid}, skipping..."
      else
        m["message"] = Base64.decode64(m["message"])
        m["subject"] = Base64.decode64(m["subject"])
        messages[msgid] = m

        log "Added new message #{msgid}."
      end
    end
  end
  
  def by_recipient
 
    #display messages

    by_recipient = {}

    messages.each do |id, m|
      toAddress = m["toAddress"]
      subject = m["subject"]
      if subject[0..3] == "Re: "
        subject = subject[4..-1]
      end
      
      by_recipient[toAddress] = {} if !by_recipient[toAddress]
      by_recipient[toAddress][subject] = [] if !by_recipient[toAddress][subject]
      by_recipient[m["toAddress"]][subject] << m
    end

    by_recipient
  end
end
