class Message

  module MessageClassMethods
    
    @@messages = []
    
    def count
      @@messages.length
    end
    
    def add(message)
      @@messages << message
    end
    
    def each!
      (@@messages.length).times do
        yield(@@messages.pop)
      end
    end
    
    def render_all
      message_string = ''
      self.each! do |message|
        message_string << message.render
      end
      message_string
    end
  end
  
  module MessageInstanceMethods
    def initialize(atts,silent=false)
      @idn = atts[:id] || "message_#{Message.count}"
      @classes = atts[:classes] || 'neutral'
      @title = atts[:title] || 'Message'
      @body = atts[:body] || ''
      Message.add(self) unless silent
    end
  
    def render()
      "<div id='#{@idn}' class='message information #{@classes}'> <h3>#{@title}</h3> <p>#{@body}</p></div>"
    end
  end
  
  class << self
    include MessageClassMethods
  end
  
  include MessageInstanceMethods
  
end