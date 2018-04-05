require 'capistrano/rails/assets'

namespace :load do
  task :defaults do
    set :precompile_env,   fetch(:rails_env) || 'production'
    set :assets_dir,       "public/assets"
    set :packs_dir,        "public/packs"
    set :rsync_cmd,        "rsync -av --delete"
  end
end

namespace :deploy do
  # Clear existing task so we can replace it rather than "add" to it.
  Rake::Task["deploy:compile_assets"].clear

  namespace :assets do

    desc "Remove all local precompiled assets"
    task :cleanup do
      run_locally do
        with rails_env: fetch(:precompile_env) do
          execute "rm -rf", fetch(:assets_dir)
          execute "rm -rf", fetch(:packs_dir)
        end
      end
    end

    desc "Actually precompile the assets locally"
    task :prepare do
      run_locally do
        env = fetch(:precompile_env)
        puts "Precompiling for env #{env}"
        unless dry_run?
          execute "RAILS_ENV=#{env} bundle exec rails assets:clean"
          execute "RAILS_ENV=#{env} bundle exec rails assets:precompile"
        end
      end
    end

    desc "Performs rsync to app servers"
    task :update do
      run_locally do
        roles(fetch(:assets_roles)).each do |host|
          assets_command = "#{fetch(:rsync_cmd)} ./#{fetch(:assets_dir)}/ #{host.user}@#{host.hostname}:#{fetch(:release_path)}/#{fetch(:assets_dir)}/"
          packs_command = "#{fetch(:rsync_cmd)} ./#{fetch(:packs_dir)}/ #{host.user}@#{host.hostname}:#{fetch(:release_path)}/#{fetch(:packs_dir)}/"

          if dry_run?
            puts assets_command
            if File.exists? fetch(:packs_dir)
              puts packs_command
            end
          else
            execute assets_command
            if File.exists? fetch(:packs_dir)
              execute packs_command
            end
          end
        end
      end
    end
  end

  after "bundler:install", "deploy:assets:prepare"
  after "deploy:updated", "deploy:assets:update"
  after "deploy:assets:update", "deploy:assets:cleanup"
end
