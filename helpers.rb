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
        message_string << "<div id='#{message[:id]}' class='message information #{message[:classes]}'>"
        message_string << "<h3>#{message[:title]}</h3>"
        message_string << "<p>#{message[:body]}</p></div>"
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
        chart_string << "</tr></thead><tbody id='#{chart[:name].gsub(/ /,'_')}_body'>"
        chart[:series].each do |series|
          chart_string << "<tr id='#{chart[:name].gsub(/ /,'_')}_series_#{series[0].gsub(/ /,'_')}'  scope='row'><th>#{series[0]}</th>"
          series[1].each do |value|
            chart_string << "<td>#{value}</td>"
          end
          chart_string << "</tr>"
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

  end

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
    seed = DateTime.parse($SETTINGS['iteration_seed'])
    seed+ (i-1)*7*$SETTINGS['iteration_length']
  end

  def iteration_end(i)
    seed = DateTime.parse($SETTINGS['iteration_seed'])
    seed+ (i)*7*$SETTINGS['iteration_length']
  end

  def current_iteration()
    get_iteration(DateTime.now)
  end

  def get_iteration(time)
    diff = time - DateTime.parse($SETTINGS['iteration_seed'])
    (diff.to_i/(7*$SETTINGS['iteration_length']))+1
  end

end
