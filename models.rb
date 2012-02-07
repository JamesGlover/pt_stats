require 'active_record'
require 'yaml'

@environment = ENV['RACK_ENV'] || 'development'
ActiveRecord::Base.establish_connection(YAML::load(File.open('./db/config.yml'))[@environment])


class Story < ActiveRecord::Base
 #validates_uniqueness_of :ticket_id
 validates_uniqueness_of :ticket_id, :scope => :rejected_close
 validates_presence_of :ticket_id
 
 # Self methods

 def self.created()
   self.where("created IS NOT NULL AND started IS NULL AND finished IS NULL AND delivered IS NULL AND accepted IS NULL AND rejected_close IS NULL AND deleted IS NULL")
 end
 
 def self.rejected()
   self.where("rejected_open IS NOT NULL AND deleted IS NULL AND rejected_close IS NULL")
 end
 
 def self.started()
   self.where("started IS NOT NULL AND finished IS NULL AND delivered IS NULL AND accepted IS NULL AND rejected_close IS NULL AND deleted IS NULL")
 end
 
 def self.finished()
   self.where("finished IS NOT NULL AND delivered IS NULL AND accepted IS NULL AND rejected_close IS NULL AND deleted IS NULL")
 end
 
 def self.delivered()
   self.where("delivered IS NOT NULL AND accepted IS NULL AND rejected_close IS NULL AND deleted IS NULL")
 end
  
 def self.accepted()
   self.where("accepted IS NOT NULL AND rejected_close IS NULL AND deleted IS NULL")
 end

 def self.total()
   self.where("created IS NOT NULL AND deleted IS NULL AND rejected_close IS NULL")
 end
 
 def self.deleted()
   self.where("deleted IS NOT NULL")
 end
 
 def self.incomplete()
   incomplete = self.where("name = :name OR ticket_type = :type OR created IS NULL AND deleted IS NULL",
   {:name => 'Unknown Story', :type => 'unknown'})
   incomplete.map do |story|
     story.ticket_id
   end
 end
 
 def self.find_by_active_ticket_id(id)
  Story.find_by_ticket_id_and_rejected_close(id,nil)
 end

 # Methods
 
 def state()
   states = ['deleted','accepted','delivered','finished','started','rejected_open','created']
   states.each do |s|
     if self.send (s+'?')
       return s unless s=='rejected_open'
       return 'rejected'
     end
   end
 end
 
 def update_state(new_state,date)
   date = Helpers.clean_date(date)
   if new_state=='rejected'
     return self.reject(date)
   end
   states = ['created','started','finished','delivered','accepted']
   return false unless states.include?(new_state)
   if (self.rejected_open? && date < self.rejected_open) # The story is rejected, but the event occured before rejection
     previous_story = Story.where("ticket_id = ? and rejected_close = ?",self.ticket_id,self.rejected_open).first
     previous_story.update_state(new_state,date)
     return false
   end
   self.send(new_state+'=', date)
   self.save
 end
 
 def reject(date)
   date = Helpers.clean_date(date)
   self.rejected_close= date
   self.rejection_count = self.rejection_count() + 1
   self.save
   Story.create!(
    :ticket_id=>self.ticket_id,
    :name=>self.name,
    :ticket_type=>self.ticket_type,
    :created=>self.created,
    :rejected_open=>date,
    :rejection_count=>self.rejection_count()
    )
 end
 
 def delete(date)
   date = Helpers.clean_date(date)
   self.deleted= date
   self.save
 end
 
end
