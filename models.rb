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

require './models/stories'
require './models/iterations'
require './models/templates'
require './models/messages'