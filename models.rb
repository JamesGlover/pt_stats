require 'active_record'
require 'yaml'
require 'pg'

@environment = ENV['RACK_ENV'] || 'development'
@environment = 'production' if ENV['DATABASE_URL']

if ENV['DATABASE_URL']
  require 'uri'
  db = URI.parse(ENV['DATABASE_URL'] || 'postgres://localhost/mydb')

  ActiveRecord::Base.establish_connection(
    :adapter  => db.scheme == 'postgres' ? 'postgresql' : db.scheme,
    :host     => db.host,
    :username => db.user,
    :password => db.password,
    :database => db.path[1..-1],
    :encoding => 'utf8'
  )
else
  ActiveRecord::Base.establish_connection(YAML::load(File.open('./db/config.yml'))[@environment])
end


class Story < ActiveRecord::Base

 #validates_uniqueness_of :ticket_id, :scope => :rejected
 validates_presence_of :ticket_id
 @environment = ENV['RACK_ENV'] || 'development'
 @environment = 'production' if ENV['DATABASE_URL']


 def self.select_state(state,i)
  states = ['created', 'started', 'finished', 'delivered', 'accepted', 'rejected']
  return [] unless states.include? state
  states.slice!(0..states.index(state))
  if i!=0
    start = iteration_start(i)
    finish = iteration_end(i)
    bound = ['created','accepted'].include?(state) ? ">= '#{start}'" : "IS NOT NULL"
    self.find_by_sql("SELECT * FROM (SELECT DISTINCT ON (ticket_id) * FROM stories WHERE deleted IS NULL AND (COALESCE(created, started, finished, delivered, accepted, rejected) < '#{finish}') ORDER BY ticket_id, id DESC ) AS x WHERE (x.#{state} < '#{finish}' AND x.#{state} #{bound}) AND (COALESCE(#{states.join(', ')}) >= '#{finish}') IS NOT FALSE ORDER BY ticket_id, id DESC")
   else
     self.find_by_sql("SELECT * FROM (SELECT DISTINCT ON (ticket_id) * FROM stories WHERE deleted IS NULL ORDER BY ticket_id, id DESC ) AS x WHERE x.#{state} IS NOT NULL AND (COALESCE(#{states.join(', ')}) IS NULL) ORDER BY ticket_id, id DESC")
   end
 end
 
 def self.created(i)
   select_state('created',i)
 end
 
 def self.started(i)
   select_state('started',i)
 end
 
 def self.finished(i)
   select_state('finished',i)
 end
 
 def self.delivered(i)
   select_state('delivered',i)
 end
  
 def self.accepted(i)
   select_state('accepted',i)
 end
 
 def self.rejected(i)

     if i !=0
       start = iteration_start(i)
       finish = iteration_end(i)
       self.find_by_sql("SELECT * FROM (SELECT DISTINCT ON (ticket_id) * FROM stories WHERE deleted IS NULL AND (COALESCE(created, started, finished, delivered, accepted, rejected) < '#{finish}') ORDER BY ticket_id ASC, id DESC ) AS x WHERE x.rejected <'#{finish}'")
     else
       self.find_by_sql("SELECT * FROM (SELECT DISTINCT ON (ticket_id) * FROM stories WHERE deleted IS NULL ORDER BY ticket_id, id DESC ) AS x WHERE x.rejected IS NOT NULL")
     end
     
 end

 def self.total(i)
   if i !=0
     start = iteration_start(i)
     finish = iteration_end(i)
     self.find_by_sql("SELECT * FROM (SELECT DISTINCT ON (ticket_id) * FROM stories WHERE deleted IS NULL AND (COALESCE(created, started, finished, delivered, accepted, rejected) < '#{finish}') ORDER BY ticket_id, id DESC ) AS x WHERE (x.accepted >= '#{start}' OR x.accepted IS NULL) AND COALESCE(started, finished, delivered, accepted, rejected ) < '#{finish}' ORDER BY ticket_id, id DESC;")
   else

    self.find_by_sql("SELECT DISTINCT ON (ticket_id) * FROM stories WHERE deleted IS NULL ORDER BY ticket_id, id DESC")

   end
 end
 
 def self.deleted(i)
   if i !=0
     start = iteration_start(i)
     finish = iteration_end(i)
   else
     self.where("deleted IS NOT NULL")
   end
 end
 
 def self.incomplete()
   incomplete = self.where("name = :name OR ticket_type = :type AND deleted IS NULL",
   {:name => 'Unknown Story', :type => 'unknown'})
   incomplete.map do |story|
     story.ticket_id
   end
 end
 
 def self.types(i,type)
   if ['bug','feature','chore','release'].include?(type)
     if i !=0
       start = iteration_start(i)
       finish = iteration_end(i)
       self.find_by_sql("SELECT * FROM (SELECT DISTINCT ON (ticket_id) * FROM stories WHERE deleted IS NULL AND (COALESCE(created, started, finished, delivered, accepted, rejected) < '#{finish}') ORDER BY ticket_id, id DESC ) AS x WHERE (x.accepted >= '#{start}' OR x.accepted IS NULL) AND COALESCE(started, finished, delivered, accepted, rejected ) < '#{finish}' AND (x.ticket_type = '#{type}') ORDER BY ticket_id, id DESC;")
     else
       self.find_by_sql("SELECT * FROM (SELECT DISTINCT ON (ticket_id) * FROM stories WHERE deleted IS NULL ORDER BY ticket_id, id DESC) AS x WHERE x.ticket_type = '#{type}'")
     end
   else
     return nil
   end
 end
 
  def self.bugs(i)
   types(i,'bug')
  end
  def self.features(i)
    types(i,'feature')
  end
  def self.chores(i)
     types(i,'chore')
  end
  def self.releases(i)
      types(i,'release')
  end


 # Methods
 
 def state()
   states = ['deleted','rejected','accepted','delivered','finished','started','created']
   states.each do |s|
     if self.send (s+'?')
       return s
     end
   end
 end
  
 def update_state(new_state,date)
   date = Helpers.clean_date(date)
   states = ['rejected','accepted','delivered','finished','started','created']
   new_state = 'created' if new_state == 'unstarted' || new_state == 'unscheduled'
   return false unless states.include?(new_state)
   return false if self.state == new_state # Don't bother updating state if it hasn't changed.
   if (self[new_state.to_sym] != nil)&&(self[new_state.to_sym] < date)
     # create a new one

     story = Story.create!( :ticket_id=>self.ticket_id, :name=>self.name,:ticket_type=>self.ticket_type )
     return story.update_state(new_state,date)
   elsif (self[new_state.to_sym] != nil)
     # We're equal or older. Little to be gained by iterating back for older tickets nothing to do here (Duplicate event?)

     return false
   else
     # Good to go    

   end

   states.each do |state| # Check we don't have more recent states
     if ( state == new_state )
       # We've got to the state, we're good to go.
       self[new_state] = date
       self.save
       return self
       break
     elsif (self[state.to_sym] !=nil && self[state.to_sym] < date )
       # We have a later state which is earlier than the event or 
       # TODO: Create a new ticket
       story = Story.create!( :ticket_id=>self.ticket_id, :name=>self.name,:ticket_type=>self.ticket_type )
       return story.update_state(new_state,date)
       break # And stop
     end
   end
 end
 
 def reject(date)
   self.update_state('rejected',date)
 end
 
 def rejection_count()
   Story.where("ticket_id = ? AND rejected IS NOT NULL AND deleted IS NULL",self.ticket_id).length
 end
 
 def ori_created()
  Story.where('ticket_id=?',ticket_id).order('id ASC').first.created
 end
 
 def ori_created=(date)
   target = Story.where('ticket_id=?',ticket_id).order('id ASC').first
   if target == nil || target == self
     self.created = date
   else # We only want to save if we've altered an unexpected record. Otherwise, leave it to the main function.
     target.created = date
     target.save
   end
 end
 
 def test_checks(id)
   comp = Story.where('id=?',id).first
   p comp
   p self
   puts "==" if comp == self
   puts "eql?" if comp.eql? self
   puts "equal?" if comp.equal? self
 end
 
 def delete(date)
  date = Helpers.clean_date(date)
  Story.find_all_by_ticket_id(self.ticket_id).each do |s|
    s.deleted= date
    s.save
  end
 end
 
end
