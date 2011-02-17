require 'rake/testtask'

task :default => [:test]

Rake::TestTask.new('test') do |t|
  t.pattern = 'test/**/tc_*.rb'
  t.verbose = true
  t.warning = true
end
