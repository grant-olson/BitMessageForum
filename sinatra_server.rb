require_relative 'message_store.rb'

$message_store = MessageStore.new

def messageHtml
  output = []
  $message_store.by_recipient.each do |user, threads|
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
  $message_store.update

  
  <<html
<html>
<head>
<title>BitBrowser!</title>
<link rel='stylesheet' type='text/css' href='/bitbrowser.css'>
</head>
<body>
<h1>Bitbrowser!</h1>
#{messageHtml}
</body>
</html>

html
end
