
# config valid only for current version of Capistrano
lock '3.6.1'

set :repo_url,            'git@github.com:prozsolt/meeting-room-dashboard.git'
set :application,         'meeting-room-dashboard'
set :user,                'zsoltprontvai'

set :use_sudo,            false
set :stage,               :production
set :deploy_via,          :remote_cache
set :deploy_to,           "/home/#{fetch(:user)}/apps/#{fetch(:application)}"
set :puma_bind,           "unix://#{shared_path}/tmp/sockets/puma.sock"
set :puma_state,          "#{shared_path}/tmp/pids/puma.state"
set :puma_pid,            "#{shared_path}/tmp/pids/puma.pid"
set :puma_access_log,     "#{release_path}/log/puma.access.log"
set :puma_error_log,      "#{release_path}/log/puma.error.log"
set :puma_preload_app,    true
set :puma_threads,        [4, 16]
set :puma_workers,        0
set :puma_worker_timeout, nil

# set :linked_files, %w{.env}

namespace :puma do
  desc 'Create Directories for Puma Pids and Socket'
  task :make_dirs do
    on roles(:app) do
      execute "mkdir #{shared_path}/tmp/sockets -p"
      execute "mkdir #{shared_path}/tmp/pids -p"
      execute "mkdir #{release_path}/log -p"
    end
  end

  before :start, :make_dirs
end

namespace :deploy do

end
