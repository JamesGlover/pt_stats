module Helpers

  def clean_date(date)
    if date.class == String
      return DateTime.parse(date)
    elsif date.class == DateTime || date.class == Time
      return date
    else
      return nil
    end
  end

  def iteration_start(i)
    DateTime.parse($SETTINGS['iteration_seed'])+ (i - 1) * 7 * $SETTINGS['iteration_length']
  end

  def iteration_end(i)
    DateTime.parse($SETTINGS['iteration_seed']) + (i) * 7 * $SETTINGS['iteration_length']
  end

  def current_iteration()
    get_iteration(DateTime.now)
  end

  def get_iteration(time)
    diff = time - DateTime.parse($SETTINGS['iteration_seed'])
    (diff.to_i/(7*$SETTINGS['iteration_length']))+1
  end
  
  def state_array(deleted=true)
    if deleted
      ['deleted','rejected','accepted','delivered','finished','started','created']
    else
      ['rejected','accepted','delivered','finished','started','created']
    end
  end

end

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

  def message_render(messages)
    message_string = ""
    messages.each do |message|
      message_string << "<div id='#{message[:id]}' class='message information #{message[:classes]}'> <h3>#{message[:title]}</h3> <p>#{message[:body]}</p></div>"
    end
    message_string
  end

  def chart_render(charts,location)
    # Will generate a div representing the chart data
    chart_string = ""
    charts.each do |chart|
      next if chart[:location] != location # Skip if it belongs elsewhere
      chart_string << "<div class='chart #{chart[:type]}' id='#{chart[:name].gsub(/ /,'_')}_chart' data-charttype='#{chart[:type]}' data-chartname='#{chart[:name].gsub(/ /,'_')}'>
      <table id='#{chart[:name].gsub(/ /,'_')}_data'>
      <caption id='#{chart[:name].gsub(/ /,'_')}_title'>#{chart[:title]}</caption>
      <thead><tr id='#{chart[:name].gsub(/ /,'_')}_head'><th scope='col'>series</th>"
      chart[:axis].each do |axis|
        chart_string<< "<th scope='col' class='axis_label'>#{axis}</th>"
      end
      chart_string << "</tr></thead>\n<tbody id='#{chart[:name].gsub(/ /,'_')}_body'>\n"
      chart[:series].each do |series|
        chart_string << "<tr id='#{chart[:name].gsub(/ /,'_')}_series_#{series[0].gsub(/ /,'_')}'  scope='row'><th>#{series[0]}</th>"
        series[1].each do |value|
          chart_string << "<td>#{value}</td>"
        end
        chart_string << "</tr>\n"
      end
      chart_string << "<span id='#{chart[:name].gsub(/ /,'_')}_json' class='json'>{#{chart[:properties]}}</span></tbody></table></div>"
    end
    return chart_string
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
    i = current_iteration()
    erb :populate, :locals => {
      :database_state => database_state,
      :project_total => database_count,
      :invalid_stories => invalid_state,
      :invalid_stories_list => invalid_list,
      :messages => messages,
      :api_token => api,
      :iteration=>i,
      :iteration_end=> iteration_end(i)
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
    tickety = <<-TICKET
    <div class='ticket' id='ticket_#{ticket.ticket_id}'>
      <h3 class='ticket_name'><a href="https://www.pivotaltracker.com/story/show/#{ticket.ticket_id}">#{ticket.name}</a></h3>
      <div class='ticket_details'><span class='ticket_state'>#{ticket.state.titleize}</span>
      <span class='ticket_id'>#{ticket.ticket_id}</span>
      <span class='ticket_created'>Created: #{ticket.ori_created.strftime("%d %B %Y %H:%M")}</span>
      <span class='ticket_started'>Started: #{ticket.started(true).strftime("%d %B %Y %H:%M")}</span>
      TICKET
    tickety << "      <span class='ticket_last_action'>#{ticket.state.titleize}: #{ticket.last_action.strftime("%d %B %Y %H:%M")}</span>\n" if ticket.state != 'started'
    tickety << <<-TICKET 
      <div class='ticket_reject_count #{ticket.rejection_count > 0 ? 'been_rejected' : 'not_rejected'}'><span class='ticket_reject_count_label'>Rejected</span>
        <span class='ticket_reject_count_counter'>#{ticket.rejection_count}</span>
        <span class='ticket_reject_count_label'>times</span>
      </div></div>
    </div>
    TICKET
  end

end