require 'active_record'
require 'yaml'

ActiveRecord::Base.establish_connection(YAML::load(File.open('./db/config.yml')))
# ActiveRecord::Base.establish_connection(
# :adapter => "mysql",
# :host => "localhost",
# :database => "pt_stories"
# )

class Story < ActiveRecord::Base
 validates_uniqueness_of :ticket_id
 validates_presence_of :ticket_id
 
 # Self methods

 def self.created()
   self.where("created IS NOT NULL AND started IS NULL")
 end
 
 def self.rejected()
   self.where("rejected IS NOT NULL AND started IS NULL")
 end
 
 def self.started()
   self.where("started IS NOT NULL AND finished IS NULL")
 end
 
 def self.finished()
   self.where("finished IS NOT NULL AND delivered IS NULL")
 end
 
 def self.delivered()
   self.where("delivered IS NOT NULL AND accepted IS NULL")
 end
  
 def self.accepted()
   self.where("accepted IS NOT NULL")
 end

 def self.total()
   self.where("created IS NOT NULL")
 end

 # Methods
 
 def state()
   states = ['accepted','delivered','finished','started','rejected','created']
   states.each do |s|
     if self.send (s+'?')
       return s
     end
   end
 end
 
 def update_state(new_state,date)
   date = DateTime.parse(date)
   states = ['created','started','finished','delivered','accepted']
   return false if new_state == 'unstarted'
   states.each do |s|
     unless self.send(s+'?')
       self.send(s+'=', date)
     end
     break if new_state==s
   end
   self.save
 end
 
 def reject(date)
   states = ['started','finished','delivered','accepted']
   states.each do |s|
     self.send(s+'=',nil)
   end
   self.rejected= DateTime.parse(date)
   self.rejection_count = self.rejection_count() + 1
   self.save
 end
 
end
