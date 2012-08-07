require "rubygems"
require "rspec/core/rake_task"

namespace :test do
  RSpec::Core::RakeTask.new(:spec) do |spec|
  end

  RSpec::Core::RakeTask.new(:coverage) do |spec|
    spec.rcov = true
    #spec.rcov_opts = %w{--exclude spec/,gems/,ruby/1.8/}
  end
end
