# Ruby charts module for providing chart data
module Charts
    
    def self.chart_states(type,name,title,iterations,location)
      series = iterations.map do |i|
        series_title = (i==0) ? ("Project") : ("Iteration #{i}")
        series_data = []
        series_data << Story.created(i).length << Story.started(i).length << Story.finished(i).length << Story.delivered(i).length << Story.accepted(i).length << Story.rejected(i).length 
        [series_title,series_data]
      end
      return {
        :location => location,
        :type => type,
        :name => name,
        :title => title,
        :axis => ['Created','Started','Finished','Delivered','Accepted','Rejected'],
        :series => series
      }
    end
    
    def self.chart_time_states(type,name,title,iteration,location)
      i_start = iteration_start(iteration)
      series = (0..$SETTINGS['iteration_length']*7-1).map do |i|
        series_title = ("Day #{i+1}")
        series_data = []
        if i_start+i < DateTime.now
          series_data << Story.created([i_start,i_start+i+1]).length << Story.started([i_start,i_start+i+1]).length << Story.finished([i_start,i_start+i+1]).length << Story.delivered([i_start,i_start+i+1]).length << Story.accepted([i_start,i_start+i+1]).length << Story.rejected([i_start,i_start+i+1]).length
        else
          # Do nothing: We don't want to break out, as we still want to build the series.
        end
        [series_title,series_data]
      end
      return {
        :location => location,
        :type => type,
        :name => name,
        :title => title,
        :axis => ['Created','Started','Finished','Delivered','Accepted','Rejected'],
        :series => series
      }
    end
    
    def self.chart_iterations_states(type,name,title,iterations,location) # iterations is a range
      i_start = iteration_start(iterations.first)
      series = (iterations).map do |i|
        series_title = ("Iteration #{i}")
        diff = (i)*$SETTINGS['iteration_length']*7
        series_data = []
        series_data << Story.created([i_start,i_start+diff]).length << Story.started([i_start,i_start+diff]).length << Story.finished([i_start,i_start+diff]).length << Story.delivered([i_start,i_start+diff]).length << Story.accepted([i_start,i_start+diff]).length << Story.rejected([i_start,i_start+diff]).length
        [series_title,series_data]
      end
      return {
        :location => location,
        :type => type,
        :name => name,
        :title => title,
        :axis => ['Created','Started','Finished','Delivered','Accepted','Rejected'],
        :series => series
      }
    end
    
    def self.chart_types(type,name,title,iterations,location)
      series = iterations.map do |i|
        series_title = (i==0) ? ("Project") : ("Iteration #{i}")
        series_data = []
        series_data << Story.bugs(i).length << Story.features(i).length << Story.chores(i).length << Story.releases(i).length
        [series_title,series_data]
      end
      return {
        :location => location,
        :type => type,
        :name => name,
        :title => title,
        :axis => ['Bug','Feature','Chore','Release'],
        :series => series
      }
    end
    
end
  