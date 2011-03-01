load 'deploy' if respond_to?(:namespace) # cap2 differentiator

set :user, 'ehsanul'
set :domain, 'ehsanul.com'

default_run_options[:pty] = true

set :repository,  "git@github.com:ehsanul/ehsanul.com.git" 
set :deploy_to, "/home/ehsanul/ehsanul.com" 
set :deploy_via, :remote_cache
set :scm, 'git'
set :branch, 'deploy'
set :git_shallow_clone, 1
set :scm_verbose, true
set :use_sudo, false
set :ssh_options, {:forward_agent => true}

server domain, :app, :web

namespace :deploy do
  task :restart do
    run "touch #{current_path}/tmp/restart.txt" 
  end
end
