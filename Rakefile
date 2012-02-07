require './web.rb'
require 'logger'
require 'yaml'

#require 'sinatra/activerecord/rake'
@environment = ENV['RACK_ENV'] || 'development'
@environment = 'production' if ENV['DATABASE_URL']

require 'uri'

namespace :db do
  
  task :environment do
    puts "Defining environment"
    @environment = ENV['RACK_ENV'] || 'development'
    puts "Environment: #{@environment}"
    require 'pg'
    require 'active_record'
     if ['development','test'].include? @environment
    #    require 'mysql'
    ActiveRecord::Base.establish_connection(YAML::load(File.open('./db/config.yml'))[@environment])
      else
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
    end

  end
  
  desc "Migrate the database"
  task(:migrate=>:environment) do
    ActiveRecord::Base.logger = Logger.new(STDOUT)
    ActiveRecord::Migration.verbose = true
    ActiveRecord::Migrator.migrate("db/migrate")
  end
  
end
  
# namespace :test do
#   require 'rake'
#   require './test/test'
# end