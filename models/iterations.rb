class Iteration

  module IterationNumber
    # Included in Fixnum
    def iteration
      Iteration.new(self)
    end
  end
  
  module IterationDate
    # Included in Date
    def iteration_number
      ((self - Iteration::SEED).seconds/(1.iterations)).to_i + 1
    end
    private :iteration_number
    
    def iteration
      Iteration.new(iteration_number)
    end

  end
  
  module IterationDuration
    # Included in Numeric, compatible with ActiveSupport::Duration
    def iterations
      ActiveSupport::Duration.new(self * Iteration::LENGTH.weeks, [[:days, self * 7 * Iteration::LENGTH]])
    end
  end
  
  module IterationClassMethods
    def current
      Time.now.iteration
    end
    
    def all
      IterationAll.instance
    end
  end
  
  module IterationInstanceMethods
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
  
  class << self  
    include IterationClassMethods
  end

  include IterationInstanceMethods

end

class IterationAll < Iteration
  include Singleton
  
  module IterationAllMethods
    def initialize
    end
  
    def start
      # Use infinity, rather than the seed, as otherwise any tickets out of bounds would not be counted.
      # While unlikely, out of bounds tickets may result from bugs, or from changes to the database seed.
      '-infinity'
    end
  
    def end
      'infinity'
    end
  
    def number
      nil
    end
  
    def all_iterations?
      true
    end
  end
  
  include IterationAllMethods

end