
module SinatraHelpers

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

  def pop_interface(api)
    database_count = Story.count
    database_state = database_count >0 ? 'populated' : 'unpopulated'

    invalid_list = Story.incomplete()
    invalid_state = invalid_list.length > 0 ? 'invalid' : 'valid'

    i = Iteration.current
    erb :populate, :locals => {
      :database_state => database_state,
      :project_total => database_count,
      :invalid_stories => invalid_state,
      :invalid_stories_list => invalid_list,
      :api_token => api,
      :iteration=>i.number,
      :iteration_end=> i.end
    }
  end

  def draw_problem_tickets()
    tickets = ""
    Story.problem_tickets().each do |ticket|
      tickets << ticket.render
    end
    tickets
  end

end