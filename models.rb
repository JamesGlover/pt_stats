require 'active_record'
require 'yaml'

@environment = ENV['RACK_ENV'] || 'development'
ActiveRecord::Base.establish_connection(YAML::load(File.open('./db/config.yml'))[@environment])


class Story < ActiveRecord::Base
 validates_uniqueness_of :ticket_id
 validates_presence_of :ticket_id
 
 # Self methods

 def self.created()
   self.where("created IS NOT NULL AND started IS NULL AND rejected IS NULL AND deleted IS NULL")
 end
 
 def self.rejected()
   self.where("rejected IS NOT NULL AND started IS NULL AND deleted IS NULL")
 end
 
 def self.started()
   self.where("started IS NOT NULL AND finished IS NULL AND deleted IS NULL")
 end
 
 def self.finished()
   self.where("finished IS NOT NULL AND delivered IS NULL AND deleted IS NULL")
 end
 
 def self.delivered()
   self.where("delivered IS NOT NULL AND accepted IS NULL AND deleted IS NULL")
 end
  
 def self.accepted()
   self.where("accepted IS NOT NULL AND deleted IS NULL")
 end

 def self.total()
   self.where("created IS NOT NULL AND deleted IS NULL")
 end
 
 def self.deleted()
   self.where("deleted IS NOT NULL")
 end
 
 def self.incomplete()
   incomplete = self.where("name = :name OR ticket_type = :type OR created = :date  AND deleted IS NULL",
   {:name => 'Unknown Story', :type => 'unknown', :date=> DateTime.parse('01/01/2000')})
   incomplete.map do |story|
     story.ticket_id
   end
 end

 # Methods
 
 def state()
   states = ['deleted','accepted','delivered','finished','started','rejected','created']
   states.each do |s|
     if self.send (s+'?')
       return s
     end
   end
 end
 
 def update_state(new_state,date)
   if new_state=='rejected'
     return self.reject(date)
   end
   date = DateTime.parse(date)
   states = ['created','started','finished','delivered','accepted']
   return false unless states.include?(new_state)
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
 
 def delete(date)
   self.deleted= DateTime.parse(date)
   self.save
 end
 
end
