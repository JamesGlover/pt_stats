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
 #validates_uniqueness_of :ticket_id
 validates_uniqueness_of :ticket_id, :scope => :rejected
 validates_presence_of :ticket_id
 @environment = ENV['RACK_ENV'] || 'development'
 @environment = 'production' if ENV['DATABASE_URL']

 # Self methods
 # Story.find_by_sql("SELECT * FROM (SELECT * FROM stories ORDER BY ticket_id ASC, id DESC ) as x GROUP BY x.ticket_id")

 def self.created(i)
     if i !=0
       start = iteration_start(i)
       finish = iteration_end(i)
       self.find_by_sql("SELECT * FROM (SELECT DISTINCT ON (ticket_id) a.*, b.rejected AS last_reject FROM stories a LEFT OUTER JOIN stories b ON ((a.ticket_id=b.ticket_id) AND (a.id!=b.id)) ORDER BY a.ticket_id, a.id DESC, b.id DESC) as x WHERE (x.deleted IS NULL) AND (x.created < '#{finish}' AND x.created >= '#{start}') AND (x.started IS NULL OR x.started >= '#{finish}') AND (x.finished IS NULL OR x.finished >= '#{finish}') AND (x.delivered IS NULL OR x.delivered >= '#{finish}') AND (x.accepted IS NULL OR x.accepted >= '#{finish}') AND (x.rejected IS NULL OR x.rejected>= '#{finish}') AND (x.last_reject IS NULL) ORDER BY ticket_id, id DESC;")
     else
       self.find_by_sql("SELECT DISTINCT ON (ticket_id) * FROM stories WHERE deleted IS NULL AND  created IS NOT NULL AND started IS NULL AND finished IS NULL AND delivered IS NULL AND accepted IS NULL AND rejected IS NULL ORDER BY ticket_id, id DESC")
     end
 end
 
 def self.rejected(i)

     if i !=0
       start = iteration_start(i)
       finish = iteration_end(i)
       self.find_by_sql("SELECT * FROM (SELECT DISTINCT ON (ticket_id) * FROM stories WHERE deleted IS NULL AND (started < '#{finish}' OR started IS NULL) ORDER BY ticket_id ASC, id DESC ) as x WHERE x.rejected <'#{finish}'")
     else
       self.find_by_sql("SELECT * FROM (SELECT DISTINCT ON (ticket_id)* FROM stories WHERE deleted IS NULL ORDER BY ticket_id, id DESC ) as x WHERE x.rejected IS NOT NULL")
     end
     
 end
 
 def self.started(i)

     if i !=0
        start = iteration_start(i)
        finish = iteration_end(i)
        self.find_by_sql("SELECT DISTINCT ON (ticket_id) * FROM stories WHERE (deleted IS NULL) AND (started IS NOT NULL AND started < '#{finish}') AND (finished IS NULL OR finished >= '#{finish}') AND (delivered IS NULL OR delivered >= '#{finish}') AND (accepted IS NULL OR accepted >= '#{finish}') AND (rejected IS NULL OR rejected>= '#{finish}') ORDER BY ticket_id, id DESC")
      else
        self.find_by_sql("SELECT DISTINCT ON (ticket_id) * FROM stories WHERE deleted IS NULL AND started IS NOT NULL AND finished IS NULL AND delivered IS NULL AND accepted IS NULL AND rejected IS NULL ORDER BY ticket_id, id DESC")
      end

 end
 
 def self.finished(i)

     if i !=0
        start = iteration_start(i)
        finish = iteration_end(i)
        self.find_by_sql("SELECT DISTINCT ON (ticket_id) * FROM stories WHERE (deleted IS NULL) AND (finished IS NOT NULL AND finished < '#{finish}') AND (delivered IS NULL OR delivered >= '#{finish}') AND (accepted IS NULL OR accepted >= '#{finish}') AND (rejected IS NULL OR rejected>= '#{finish}') ORDER BY ticket_id, id DESC")
      else
        self.find_by_sql("SELECT DISTINCT ON (ticket_id) * FROM stories WHERE deleted IS NULL AND finished IS NOT NULL AND delivered IS NULL AND accepted IS NULL AND rejected IS NULL ORDER BY ticket_id, id DESC")
      end
  
 end
 
 def self.delivered(i)

     if i !=0
        start = iteration_start(i)
        finish = iteration_end(i)
        self.find_by_sql("SELECT DISTINCT ON (ticket_id) * FROM stories WHERE (deleted IS NULL) AND (delivered IS NOT NULL AND delivered < '#{finish}') AND (accepted IS NULL OR accepted >= '#{finish}') AND (rejected IS NULL OR rejected>= '#{finish}') ORDER BY ticket_id, id DESC")
      else
        self.find_by_sql("SELECT DISTINCT ON (ticket_id) * FROM stories WHERE deleted IS NULL AND delivered IS NOT NULL AND accepted IS NULL AND rejected IS NULL ORDER BY ticket_id, id DESC")
      end

 end
  
 def self.accepted(i)

     if i !=0
         start = iteration_start(i)
         finish = iteration_end(i)
         self.find_by_sql("SELECT DISTINCT ON (ticket_id) * FROM stories WHERE (deleted IS NULL) AND (accepted >= '#{start}' AND accepted < '#{finish}') AND (rejected IS NULL OR rejected>= '#{finish}') ORDER BY ticket_id, id DESC")
       else
         self.find_by_sql("SELECT DISTINCT ON (ticket_id) * FROM stories WHERE deleted IS NULL AND accepted IS NOT NULL AND rejected IS NULL ORDER BY ticket_id, id DESC")
       end

 end

 def self.total(i)
   if i !=0
     start = iteration_start(i)
     finish = iteration_end(i)
     self.find_by_sql("SELECT * FROM (SELECT DISTINCT ON (ticket_id) a.*, b.rejected AS last_reject FROM stories a LEFT OUTER JOIN stories b ON ((a.ticket_id=b.ticket_id) AND (a.id!=b.id)) ORDER BY a.ticket_id, a.id DESC, b.id DESC) as x WHERE (x.deleted IS NULL) AND ((x.started < '#{finish}' OR (x.started IS NULL AND x.rejected < '#{finish}')) OR (x.last_reject < '#{finish}')) AND (x.accepted >= '#{start}' OR x.accepted IS NULL) ORDER BY ticket_id, id DESC;")
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
   incomplete = self.where("name = :name OR ticket_type = :type OR created IS NULL AND deleted IS NULL",
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
       self.find_by_sql("SELECT * FROM (SELECT DISTINCT ON (ticket_id) a.*, b.rejected AS last_reject FROM stories a LEFT OUTER JOIN stories b ON ((a.ticket_id=b.ticket_id) AND (a.id!=b.id)) ORDER BY a.ticket_id, a.id DESC, b.id DESC) as x WHERE (x.deleted IS NULL) AND ((x.started < '#{finish}' OR (x.started IS NULL AND x.rejected < '#{finish}')) OR (x.last_reject < '#{finish}')) AND (x.accepted >= '#{start}' OR x.accepted IS NULL) AND (x.ticket_type = '#{type}') ORDER BY ticket_id, id DESC;")
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
   if new_state=='rejected'
     return self.reject(date)
   end
   states = ['created','started','finished','delivered','accepted']
   return false unless states.include?(new_state)
   if (!self.rejected? || (self.rejected? && date < self.rejected)) # We're not rejected, or the even pre-dates rejection
     self.send(new_state+'=', date)
     self.save
   else # We're rejected, and the event is after rejection
     story = Story.create!(
      :ticket_id=>self.ticket_id,
      :name=>self.name,
      :ticket_type=>self.ticket_type,
      :created=>self.created
      )
      story.update_state(new_state,date)
    end
 end
 
 def reject(date)
   date = Helpers.clean_date(date)
   self.rejected = date
   self.save
 end
 
 def rejection_count()
   Story.where("ticket_id = ? AND rejected IS NOT NULL AND deleted IS NULL",self.ticket_id).length
 end
 
 def delete(date)
  date = Helpers.clean_date(date)
  Story.find_all_by_ticket_id(self.ticket_id).each do |s|
    s.deleted= date
    s.save
  end
 end
 
end
