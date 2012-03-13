class Story < ActiveRecord::Base
  
  validates_presence_of :ticket_id

  module StoryClassMethods
        def select_state(state,i)
      states = State.array(false).reverse
      return [] unless states.include? state
      states.slice!(0..states.index(state))
      if (i.is_a? Iteration) && (i.all_iterations?)
        self.find_by_sql("
          SELECT * 
          FROM (
            SELECT DISTINCT ON (ticket_id) * FROM stories
            WHERE deleted IS NULL
            ORDER BY ticket_id, id DESC )
          AS x 
          WHERE x.#{state} IS NOT NULL
          AND (COALESCE(#{states.join(', ')}) IS NULL)
          ORDER BY ticket_id, id DESC")
      else
        start = i.start
        finish = i.end
        bound = ['created','accepted'].include?(state) ? ">= '#{start}'" : "IS NOT NULL"
        self.find_by_sql("
          SELECT *
          FROM (
            SELECT DISTINCT ON (ticket_id) * FROM stories
            WHERE deleted IS NULL
            AND (COALESCE(created, started, finished, delivered, accepted, rejected) < '#{finish}')
            ORDER BY ticket_id, id DESC )
          AS x 
          WHERE (x.#{state} < '#{finish}'
          AND x.#{state} #{bound})
          AND (COALESCE(#{states.join(', ')}) >= '#{finish}') IS NOT FALSE
          ORDER BY ticket_id, id DESC")
      end
    end

    def created(i)
      select_state('created',i)
    end

    def started(i)
      select_state('started',i)
    end

    def finished(i)
      select_state('finished',i)
    end

    def delivered(i)
      select_state('delivered',i)
    end

    def accepted(i)
      select_state('accepted',i)
    end

    def rejected(i)
      if (i.is_a? Iteration) && (i.all_iterations?)
        self.find_by_sql("
          SELECT * 
          FROM (
            SELECT DISTINCT ON (ticket_id) *
            FROM stories
            WHERE deleted IS NULL 
            ORDER BY ticket_id, id DESC )
          AS x WHERE x.rejected IS NOT NULL")
      else
        start = i.start
        finish = i.end
        self.find_by_sql("
          SELECT * 
          FROM (
            SELECT DISTINCT ON (ticket_id) *
            FROM stories
            WHERE deleted IS NULL
            AND (COALESCE(created, started, finished, delivered, accepted, rejected) < '#{finish}')
            ORDER BY ticket_id ASC, id DESC )
          AS x
          WHERE x.rejected <'#{finish}'")
      end

    end

    def total(i)
      if (i.is_a? Iteration) && (i.all_iterations?)
        self.find_by_sql("
          SELECT DISTINCT ON (ticket_id) *
          FROM stories
          WHERE deleted IS NULL
          ORDER BY ticket_id, id DESC")
      else
        start = i.start
        finish = i.end
        self.find_by_sql("
          SELECT *
          FROM (
            SELECT DISTINCT ON (ticket_id) *
            FROM stories 
            WHERE deleted IS NULL
            AND (COALESCE(created, started, finished, delivered, accepted, rejected) < '#{finish}')
            ORDER BY ticket_id, id DESC )
          AS x 
          WHERE (
            x.accepted >= '#{start}'
            OR x.accepted IS NULL)
          AND COALESCE(started, finished, delivered, accepted, rejected ) < '#{finish}'
          ORDER BY ticket_id, id DESC;")
      end
    end

    def deleted(i)
      if (i.is_a? Iteration) && (i.all_iterations?)
        self.where("deleted IS NOT NULL")

      else
        start = i.start
        finish = i.end
        self.find_by_sql("
          SELECT *
          FROM (
            SELECT DISTINCT ON (ticket_id) *
            FROM stories
            WHERE (COALESCE(created, started, finished, delivered, accepted, rejected) < '#{finish}')
            ORDER BY ticket_id ASC, id DESC )
          AS x
          WHERE x.deleted >= '#{start}'
          AND x.deleted <'#{finish}'")
      end
    end

    def incomplete
      incomplete = self.where("name = :name OR ticket_type = :type AND deleted IS NULL",
      {:name => 'Unknown story', :type => 'unknown'})
      incomplete.map(&:ticket_id)
    end

    def types(i,type)
      if ['bug','feature','chore','release'].include?(type)
        if !i.all_iterations?
          start = i.start
          finish = i.end
          self.find_by_sql("
            SELECT *
            FROM (
              SELECT DISTINCT ON (ticket_id) *
              FROM stories
              WHERE deleted IS NULL
              AND (COALESCE(created, started, finished, delivered, accepted, rejected) < '#{finish}')
              ORDER BY ticket_id, id DESC )
            AS x 
            WHERE (
              x.accepted >= '#{start}' 
              OR x.accepted IS NULL)
            AND COALESCE(started, finished, delivered, accepted, rejected ) < '#{finish}'
            AND (x.ticket_type = '#{type}')
            ORDER BY ticket_id, id DESC;")
        else
          self.find_by_sql("
            SELECT *
            FROM (
              SELECT DISTINCT ON (ticket_id) *
              FROM stories
              WHERE deleted IS NULL
              ORDER BY ticket_id, id DESC)
            AS x
              WHERE x.ticket_type = '#{type}'")
        end
      else
        return nil
      end
    end
    private :types

    def bugs(i)
      types(i,'bug')
    end
  
    def features(i)
      types(i,'feature')
    end
  
    def chores(i)
      types(i,'chore')
    end
  
    def releases(i)
      types(i,'release')
    end
  
    def problem_tickets(i=Iteration.current)
      # Problem tickets returns a has of tickets that may need special attention
      # Main selector = Started in previous iterations not rejected or finished
      # Tickets with more than one rejection TODO: Adjust function to be iteration aware
      old_and_stalled_tickets(i)|rejected_more_than(1)
    end
  
    def old_and_stalled_tickets(iteration)
      self.find_by_sql("
        SELECT *
        FROM (
          SELECT DISTINCT ON (ticket_id) *
          FROM stories 
          WHERE deleted IS NULL 
          ORDER BY ticket_id, id DESC)
        AS x 
        WHERE (x.rejected IS NULL OR x.rejected > '#{iteration.end}')
        AND (x.accepted IS NULL OR x.rejected > '#{iteration.end}')
        AND COALESCE(x.started, x.finished, x.delivered) < '#{iteration.start}'
        ORDER BY ticket_id, id DESC;")
    end
  
    def rejected_more_than(count)
      self.find_by_sql("
        SELECT *
        FROM stories 
        WHERE id IN (
          SELECT max(id)
          FROM stories
          WHERE deleted IS NULL
          GROUP BY ticket_id
          HAVING count(distinct rejected)>#{count})
          AND accepted IS NULL;")
    end
  end

  module StoryInstanceMethods
    def clone(args={})
      Story.create!( { :ticket_id=>self.ticket_id, :name=>self.name,:ticket_type=>self.ticket_type }.merge(args) )
    end

    def state
      State.array.each do |s|
        if sd = self.send(s)
          return State.new(s, sd)
        end
      end
      nil
    end

    def target_ticket(new_state)
      return nil if new_state.no_change?(self.state, self)
      return self.clone if new_ticket_required?(new_state)
      self
    end

    def new_ticket_required?(new_state) 
      State.array.each do |state|
        if (self[state.to_sym] !=nil && self[state.to_sym] < new_state.date )
          return true
        elsif ( state == new_state.name )
          return false
        end
      end
    end

    def update_state(requested_state,date)
      new_state = State.new(requested_state,date)
      if target = target_ticket(new_state)
        target[new_state.name.to_sym] = new_state.date
        target.save
      end
      target
    end

    def reject(date)
      self.update_state('rejected',date)
    end

    def rejection_count
      Story.where("ticket_id = ? AND rejected IS NOT NULL AND deleted IS NULL",self.ticket_id).length
    end
  
    def find_ticket_stack
      Story.find_all_by_ticket_id_and_deleted(self.ticket_id,nil, :order=> 'id DESC')
    end
  
    def entered_state(attribute,iterate=fasle)
      if iterate
        return read_attribute(attribute) unless read_attribute(attribute).nil?
        return nil if (State.array.index(attribute)<=self.state.index)
        stack = find_ticket_stack
        return nil if stack.empty?
        (stack.index(self)..stack.length-1).each do |i|
          return stack[i].read_attribute(attribute) unless stack[i].read_attribute(attribute).nil?
        end
        return 'Unknown'
      else
        read_attribute(attribute)
      end
    end
    private :entered_state
  
    def created(iterate=false)
      entered_state("created",iterate)
    end
    def started(iterate=false)
      entered_state("started",iterate)
    end
    def finished(iterate=false)
      entered_state("finished",iterate)
    end
    def delivered(iterate=false)
      entered_state("delivered",iterate)
    end
    def accepted(iterate=false)
      entered_state("accepted",iterate)
    end
    def rejected(iterate=false)
      entered_state("rejected",iterate)
    end

    def ori_created
      Story.where('ticket_id=?',ticket_id).order('id ASC').first.created
    end

    def ori_created=(date)
      target = Story.where('ticket_id=?',ticket_id).order('id ASC').first
      if target.nil? || target == self
        self.created = date
      else # We only want to save if we've altered an unexpected record. Otherwise, leave it to the main function.
        target.created = date
        target.save
      end
    end

    def delete(date)
      date = date.to_time
      Story.find_all_by_ticket_id(self.ticket_id).each do |s|
        s.deleted= date
        s.save
      end
    end
  
    def last_action # Returns Time of latest state change
      State.array.each do |state|
        return self[state] if self[state] != nil
      end
    end
  
    def update_details(story)
      self.name = story.name || self.name || "Unknown story"
      self.ticket_type = story.ticket_type || self.ticket_type || 'unknown'
      self.save
    end
  end
  
  class << self
    include StoryClassMethods
  end
  
  include StoryInstanceMethods

  
  
  class State
    
    module StateClassMethods
      def array(deleted=true)
        if deleted
          ['deleted','rejected','accepted','delivered','finished','started','created']
        else
          ['rejected','accepted','delivered','finished','started','created']
        end
      end
    end
    
    module StateInstanceMethods
      attr_reader :date, :name

      def initialize(name,date)
        name = 'created' if ['unstarted','unscheduled'].include?(name)
        @name = name
        @date = date.to_time
        @valid = validate_state
      end
    
      def validate_state
        State.array.include?(@name)
      end
      private :validate_state
    
      def valid?
        @valid
      end
    
      def invalid?
        !@valid
      end

      def index
        @index ||= State.array.index(@name)
      end
    
      def changed_since?(previous)
        @name == previous.try(:name)
      end
    
      def exists_on?(ticket)
        !ticket[@name.to_sym].nil?
      end
    
      def ==(b)
        @name == b.name && @date == b.date
      end
    
      def no_change?(old_state,ticket)
        invalid? || changed_since?(old_state) || ( exists_on?(ticket) && (ticket[@name.to_sym] >= @date))
      end
    end
    
    class << self
      include StateClassMethods
    end

    include StateInstanceMethods
    
  end
  
end