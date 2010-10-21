require 'jeweler'

Jeweler::Tasks.new do |s|
	s.name = "lark"
	s.description = "A system for nodes to communicate state and presence through a redis cluster"
	s.summary = s.description
	s.author = "Orion Henry"
	s.email = "orion@heroku.com"
	s.homepage = "http://github.com/orionz/lark"
	s.rubyforge_project = "lark"
	s.files = FileList["[A-Z]*", "{lib,spec}/**/*"]
	s.add_dependency "redis",  [">= 2.0.5"]
end

Jeweler::RubyforgeTasks.new

desc 'Run specs'
task :spec do
	sh 'bacon -s spec/*_spec.rb'
end

task :default => :spec

