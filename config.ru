$LOAD_PATH.unshift *Dir.entries('/home/ehsanul/.gem/ruby/1.8/gems').map{|gem|File.join '/home/ehsanul/.gem/ruby/1.8/gems', gem, 'lib'}
require 'rack'
require 'sinatra'

set :run, false
set :environment, :production
set :views, File.join(File.dirname(__FILE__), 'views')

require 'ehsanul.com.rb'
run Sinatra::Application 
