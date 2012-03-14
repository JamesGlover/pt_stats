
class Fixnum
  include Iteration::IterationNumber
end

class Numeric 
  #Passed in to Numeric for consistancy with other ActiveSupport::Duration functions
  include Iteration::IterationDuration
end

class Time
  include Iteration::IterationDate
end

class Time
  include Iteration::IterationDate
end

class String
  def strftime(*args)
    return self
  end
end

class Array
  
  def start
    self[0].to_time
  end
  
  def end
    self.last.to_time
  end
  
  def to_ul(cls)
    ul = "<ul class='#{cls}'>"
    self.each do |item|
      ul << "<li>#{item}</li>"
    end
    ul << '</ul>'
  end
  
end