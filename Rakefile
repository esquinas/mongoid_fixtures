# frozen_string_literal: true

require 'bundler/gem_tasks'

require 'rspec/core/rake_task'

task default: [:spec]

RSpec::Core::RakeTask.new do |t|
  t.pattern = './spec/mongoid_fixtures_spec.rb'
end
