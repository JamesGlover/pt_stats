class Iteration

  module IterationNumber
    def iteration
      Iteration.new(self)
    end
  end
  
  module IterationDate
    
    def iteration_number
      ((self - Iteration::SEED).seconds/(1.iterations)).to_i + 1
    end
    private :iteration_number
    
    def iteration
      Iteration.new(iteration_number)
    end

  end
  
  module IterationDuration
    def iterations
      ActiveSupport::Duration.new(self * Iteration::LENGTH.weeks, [[:days, self * 7 * Iteration::LENGTH]])
    end
  end

  class << self  
    # Class methods/variables
    def current
      Time.now.iteration
    end
    
    def all
      IterationAll.instance
    end

  end

  # Instance methods/variables
  attr_reader :number
  
  def initialize(number)
    @number = number
  end
  
  def start
    @start ||= (@number - 1).iterations.since(Iteration::SEED)
  end
  
  def end
    @end ||= 1.iterations.since(self.start)
  end
  
  def all_iterations?
    false
  end

end

class IterationAll < Iteration
  include Singleton
  
  def initialize
  end
  
  def start
    Iteration::SEED
  end
  
  def end
    Time.now
  end
  
  def number
    nil
  end
  
  def all_iterations?
    true
  end

end