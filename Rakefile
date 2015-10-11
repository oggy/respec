require 'ritual'

task :ci do
  sh 'git config user.name || git config user.name Test'
  sh 'git config user.email || git config user.email test@example.com'
  sh 'bundle exec rspec spec'
end
