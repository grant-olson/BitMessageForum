#!/usr/bin/env ruby
require_relative 'threaded_messages.rb'

def messageHtml
  output = []
  ThreadedMessages.by_recipient.each do |user, threads|
    output << "<div class='recipient'>"
    output << "<h2>TO: #{user}</h2>"
    threads.each do |thread, messages|
      output << "<div class='thread'>"
      output << "<h3>THREAD: #{thread}</h3>"
      messages.each do |message|
        output << "<div class='message'>"
        output << "<h4>FROM: #{message['fromAddress']}</h4>"
        body = message['message']
        body = body.split("\n").map { |line| line.strip}.select {|line| line != ""}
        body.each do |paragraph|
          
          if paragraph == "------------------------------------------------------"
            output << "<p><em>Show quoted text</em></p>"
            # output << "<hr />"
            break
          else
            output << "<p>#{CGI::escape_html(paragraph)}</p>"
          end
          
        end
        output << "</div>"
        
      end
      output << "</div>"
    end
    output << "</div>"
  end

  output.join("\n")
end

require 'sinatra'

get "/", :provides => :html do
  <<html
<html>
<head>
<title>BitBrowser!</title>
<style type='text/css'>
.recipient, .thread, .message {
  border: 1pt solid black;
}

body {
  background-color: #666666;
  font-family: sans-serif;
  font-size: 75%;
}

div { margin: 0.5em;padding:0.5em }

.recipient { background-color:#999999;}
.thread { background-color:#BBBBBB;}
.message { background-color:#EEEEEE;}
</style>
</head>
<body>
<h1>Bitbrowser!</h1>
#{messageHtml}
</body>
</html>

html
end
