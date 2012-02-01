require './web.rb'
require 'logger'
require 'yaml'

#require 'sinatra/activerecord/rake'

namespace :db do
  
  task :environment do
    puts "Defining environment"
    require 'active_record'
    require 'mysql'
    ActiveRecord::Base.establish_connection(YAML::load(File.open('./db/config.yml')))
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
#   require 'rake/tests'
#   #require './test/test'
#   puts "Testing"
#   Rake::TestTask.new do |t|
#       t.libs << "test"
#       t.test_files = FileList['test/test*.rb']
#       t.verbose = true
#     end
# end