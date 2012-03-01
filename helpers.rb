
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

  def chart_render(charts,location)
    template = Template.new('table')
    chart_string =""
    charts.map do |chart|
      next if chart[:location] != location
      template.fill(binding)
    end.join('')
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
    database_state = database_count >0 ? 'populated' : 'unpopulated'

    invalid_list = Story.incomplete()
    invalid_state = invalid_list.length > 0 ? 'invalid' : 'valid'

    i = Iteration.current
    erb :populate, :locals => {
      :database_state => database_state,
      :project_total => database_count,
      :invalid_stories => invalid_state,
      :invalid_stories_list => invalid_list,
      :messages => messages,
      :api_token => api,
      :iteration=>i.number,
      :iteration_end=> i.end
    }
  end

  def draw_problem_tickets()
    tickets = ""
    Story.problem_tickets().each do |ticket|
      tickets << render_ticket(ticket)
    end
    tickets
  end 

  def render_ticket(ticket)
    Template.new('ticket').fill(binding)
  end

end