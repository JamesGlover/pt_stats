# Ruby charts module for providing chart data
# Need to be re-thought
module Charts
  
    def self.simple(args)
      chart = Chart.new(args)
      chart.update
      chart.instance_variable_get(:@args)
    end

    def self.chart_time_states(args)
      chart = TimeChart.new(args)
      chart.update
      chart.instance_variable_get(:@args)
    end
    
    def self.chart_iterations_states(args)
      chart = IterationChart.new(args)
      chart.update
      chart.instance_variable_get(:@args)
    end
    
end

class Chart
  
  module ChartClassMethods
    @@charts = {}
    
    def register(args)
      @@charts[args[:name]] = self.new(args)
    end
    
    def update_all
      @@charts.each do |k,v|
        v.update
      end
    end
    
    def update_in(location )
      @@charts.each do |k,v|
        v.update if v.location == location
      end
    end
    
    def render_all(location=nil)
      string = ''
      @@charts.each do |name,chart|
        chart.update if chart.no_data?
        string << chart.render if !location.nil? && chart.location == location
      end
      string
    end
    alias :render_all_in :render_all
    
    def named(name)
      @@charts[name]
    end
  end
  
  class << self
    include ChartClassMethods
  end
  
  module ChartInstanceMethods
    def collect_data(time)
      @args[:axis].map do |variable|
        Story.public_send(variable.downcase.to_sym,time).length
      end
    end
  
    def initialize(args)
      @args = args
    end
  
    def update
        @args[:series] = @args[:iterations].map do |i|
          series_title = (i.all_iterations?) ? ("Project") : ("Iteration #{i.number}")
          [series_title, collect_data(i)]
        end
    end
  
    def render
      args = @args
      template = Template.new('table')
      template.fill(binding)
    end
  
    def location
      @args[:location]
    end
  
    def no_data?
      @args[:series].nil?
    end
  end
  include ChartInstanceMethods
  
end

class TimeChart < Chart
  module TimeChartMethods
    def update
      chart_start = @args[:iteration].start
      @args[:series] = (0..Iteration::LENGTH*7-1).map do |i|
        series_title = ("Day #{i+1}")
        if chart_start+i.days < Time.now
          series_data = self.collect_data([chart_start, chart_start+(i+1).days])
        else
          series_data=[]
        end
        [series_title,series_data]
      end
    end
  end
  include TimeChartMethods
end

class IterationChart < Chart
  module IterationChartMethods
    def update
      chart_start = @args[:iteration_range].first.iteration.start
      @args[:series] = (@args[:iteration_range]).map do |i|
        series_title = ("Iteration #{i}")
        [series_title, self.collect_data([chart_start, i.iteration.end])]
      end
    end
  
    def iteration_range=(range)
      @args[:iteration_range]=range
    end
  end
  include IterationChartMethods
end