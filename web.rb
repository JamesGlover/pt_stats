# Pivotal Tracker stats analyzer and information radiator

# Setup external requirements
require 'sinatra'
require 'rubygems'
require 'erb'
require 'yaml'
require 'rexml/document'
require 'bcrypt'

# Require the rest of our application
require './models'
require './pt_api'
require './helpers'
require './charts'

# Setup globals
@environment = ENV['RACK_ENV'] || 'development'
$SETTINGS = YAML::load(File.open('./config.yml'))[@environment]
$SETTINGS['bucket_code'] = ENV['BUCKET_CODE'] || $SETTINGS['bucket_code']
$SETTINGS['username'] = ENV['USERNAME'] || $SETTINGS['username']
$SETTINGS['hash_password'] = ENV['HASH_PASSWORD'] || $SETTINGS['hash_password']
$SETTINGS['project_id'] = ENV['PROJECT_ID'].to_i if ENV['PROJECT_ID']
$SETTINGS['project_name'] = ENV['PROJECT_NAME'] || $SETTINGS['project_name']
$SETTINGS['iteration_seed'] = ENV['ITERATION_SEED'] || $SETTINGS['iteration_seed']
$SETTINGS['iteration_length'] = ENV['ITERATION_LENGTH'].to_i if ENV['ITERATION_LENGTH']
$SETTINGS['api_token'] = ENV['API_TOKEN'] || $SETTINGS['api_token']

require './routes'