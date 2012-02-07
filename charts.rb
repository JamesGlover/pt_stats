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
  