require 'rake/testtask'
require 'rubygems/tasks'

Gem::Tasks.new

Rake::TestTask.new do |t|
  t.libs = ['lib', 'test']
  t.name = 'test'
  t.description = 'Run all tests'
  t.warning = true
  t.test_files = FileList['test/*.rb']
end

FileList['test/*.rb'].each do |p|
  name = p.split('/').last.split('.').first
  Rake::TestTask.new do |t|
    t.libs = ['lib', 'test']
    t.name = "test:#{name}"
    t.description = "Run only #{name} specific tests"
    t.warning = true
    t.test_files = [p]
  end
end
