require_relative 'xmlrpc_client.rb'
require 'json'
require 'base64'

module ThreadedMessages
  def self.by_recipient
    client = XmlrpcClient.new

    inbox_messages = JSON.parse client.getAllInboxMessages


    inbox = inbox_messages['inboxMessages']

    messages = {}

    # fix messages
    inbox.each do |m|
      m["message"] = Base64.decode64(m["message"])
      m["subject"] = Base64.decode64(m["subject"])
      messages[m["msgid"]] = m
    end

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
