module Helpers
  
  helpers do
    
    def protected!
      unless authorized?
        response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
        throw(:halt, [401, "Not authorized\n"])
      end
    end

    def authorized?
      @auth ||=  Rack::Auth::Basic::Request.new(request.env)
      if @auth.provided? && @auth.basic? && @auth.credentials
        @hash_password = $SETTINGS['hash_password']
        @saved_password = BCrypt::Password.new(@hash_password)  
        if @auth.credentials[0]== $SETTINGS['username'] && @saved_password == @auth.credentials[1]
          return true
        end    
      end
    end
    
    def message_render(messages)
      message_string = ""
      messages.each do |message|
        message_string << "<div id='#{message[:id]}' class='information #{message[:classes]}'>"
        message_string << "<h3>#{message[:title]}</h3>"
        message_string << "<p>#{message[:body]}</p></div>"
      end
      message_string
    end

    def idlist_render(stories)
      stories_string = "<ul class='invalid_list'>"
      stories.each do |story|
        stories_string << "<li>#{story}</li>"
      end
      stories_string << '</ul>'
    end
    
    def pop_interface(messages,api)
      database_count = Story.count
      if database_count >0
        database_state = 'populated'
      else
        database_state = 'unpopulated'
      end

      invalid_list = Story.incomplete()
      if invalid_list.length > 0
        invalid_state = 'invalid'
      else
        invalid_state = 'valid'
      end

      erb :populate, :locals => {
        :database_state => database_state,
        :project_total => database_count,
        :invalid_stories => invalid_state,
        :invalid_stories_list => invalid_list,
        :messages => messages,
        :api_token => api
      }
    end
    
  end
  
end
