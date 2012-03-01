# Ruby charts module for providing chart data
module Charts
  
    def self.simple(args)#type,name,title,iterations,location, properties='',axis)
      args[:series] = args[:iterations].map do |i|
        series_title = (i.all_iterations?) ? ("Project") : ("Iteration #{i.number}")
        [series_title, self.collect_data(i,args[:axis])]
      end
      args
    end

    def self.chart_time_states(args)
      chart_start = args[:iteration].start
      args[:series] = (0..Iteration::LENGTH*7-1).map do |i|
        series_title = ("Day #{i+1}")
        if chart_start+i.days < Time.now
          series_data = self.collect_data([chart_start, chart_start+(i+1).days],args[:axis])
        else
          series_data=[]
        end
        [series_title,series_data]
      end
      args
    end
    
    def self.chart_iterations_states(args)
      chart_start = args[:iteration_range].first.iteration.start
      args[:series] = (args[:iteration_range]).map do |i|
        series_title = ("Iteration #{i}")
        [series_title, self.collect_data([chart_start, i.iteration.end],args[:axis])]
      end
      args
    end
    
    def self.collect_data(time,axis)
      axis.map do |variable|
        Story.public_send(variable.downcase.to_sym,time).length
      end
    end
end
  