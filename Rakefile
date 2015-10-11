require 'ritual'

task :ci do
  sh 'git config --global user.name || git config --global user.name Test'
  sh 'git config --global user.email || git config --global user.email test@example.com'
  sh 'bundle exec rspec spec'
end
