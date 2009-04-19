require 'rubygems'

gem 'cucumber', '>=0.3'
require 'cucumber'

gem 'spicycode-rcov', '>=0.8.1.5.0'
require 'rcov'
require 'spec'

$:.unshift(File.dirname(__FILE__)) 
require 'cucover/monkey'
require 'cucover/rails'
require 'cucover/lazy_test_case'
require 'cucover/lazy_scenario'
require 'cucover/lazy_step_invocation'

module Cucover
  class TestIdentifier < Struct.new(:file, :line, :depends_on)
    def initialize(file, line, depends_on = nil)
      super
      self.freeze
    end
  end
  
  class CoverageRecording
    def initialize(test_identifier)
      @analyzer = Rcov::CodeCoverageAnalyzer.new        
      @cache = SourceFileCache.new(test_identifier)
      @covered_files = []
    end
    
    def record_file(source_file)
      @covered_files << source_file unless @covered_files.include?(source_file)
    end
    
    def record_coverage
      @analyzer.run_hooked do
        yield
      end
      @covered_files.concat @analyzer.analyzed_files
    end
    
    def save
      @cache.save normalized_files
    end
    
    private
    
    def normalized_files
      @covered_files.map{ |f| File.expand_path(f).gsub(/^#{Dir.pwd}\//, '') }
    end
  end
  
  class Executor
    def initialize(test_identifier)
      @source_files_cache = SourceFileCache.new(test_identifier)      
      @status_cache       = StatusCache.new(test_identifier)
      @dependency         = test_identifier.depends_on
    end
    
    def should_execute?
      dirty? || failed_on_last_run? || dependency_should_execute?
    end
    
    private
    
    def dependency_should_execute?
      return false unless @dependency
      Executor.new(@dependency).should_execute?
    end
    
    def failed_on_last_run?
      return false unless @status_cache.exists?
      @status_cache.last_run_status == "failed"
    end
    
    def dirty?
      return true unless @source_files_cache.exists?
      @source_files_cache.any_dirty_files?
    end
  end
  
  class TestMonitor
    def initialize(test_identifier, visitor)
      @test_identifier, @visitor = test_identifier, visitor
      @coverage_recording = CoverageRecording.new(test_identifier)
      @status_cache       = StatusCache.new(test_identifier)
      @executor           = Executor.new(test_identifier)
    end
    
    def record(source_file)
      @coverage_recording.record_file(source_file)
    end
    
    def fail!
      @failed = true
    end
    
    def watch(&block)
      announce_skip unless should_execute?

      @coverage_recording.record_file(@test_identifier.file)
      @coverage_recording.record_coverage(&block)
      @coverage_recording.save
      
      @status_cache.record(status)
    end
    
    def should_execute?
      @executor.should_execute?
    end
    
    private
    
    def status
      @failed ? :failed : :passed
    end
    
    def announce_skip
      @visitor.announce "[ Cucover - Skipping clean scenario ]"
    end
  end
  
  class << self
    def start_test(test_identifier, visitor, &block)
      @current_test = TestMonitor.new(test_identifier, visitor)
      @current_test.watch(&block)
    end
    
    def fail_current_test!
      current_test.fail!
    end
    
    def record(source_file)
      current_test.record(source_file)
    end
    
    def can_skip?
      not current_test.should_execute?
    end
    
    private
    
    def current_test
      @current_test or raise("You need to start the a test first!")
    end
  end
  
  class Cache
    def initialize(test_identifier)
      @test_identifier = test_identifier
    end
    
    def exists?
      File.exist?(cache_file)
    end
    
    private
    
    def cache_file
      cache_folder + '/' + cache_filename
    end
    
    def cache_folder
      @test_identifier.file.gsub(/([^\/]*\.feature)/, ".coverage/\\1/#{@test_identifier.line.to_s}")
    end
    
    def time
      File.mtime(cache_file)
    end

    def write_to_cache
      FileUtils.mkdir_p File.dirname(cache_file)
      File.open(cache_file, "w") do |file|
        yield file
      end
    end
    
    def cache_content
      File.readlines(cache_file)
    end
  end
  
  class StatusCache < Cache
    def last_run_status
      cache_content.to_s.strip
    end
    
    def record(status)
      write_to_cache do |file|
        file.puts status
      end
    end
    
    private

    def cache_filename
      'last_run_status'
    end
  end
  
  class SourceFileCache < Cache
    def save(analyzed_files)
      write_to_cache do |file|
        file.puts analyzed_files
      end
    end
    
    def any_dirty_files?
      not dirty_files.empty?
    end
    
    private
    
    def cache_filename
      'covered_source_files'
    end

    def source_files
      cache_content
    end

    def dirty_files
      source_files.select do |source_file|
        File.mtime(source_file.strip) >= time
      end
    end
  end
end

# the way scenario and background behave needs to be different. 
# scenarios should inherit their re-run triggers from backgrounds, so that if a background is changed, all the scenarios are re-run
# also if a background is used by a scenario that will be re-run, we mustn't skip the background's step executions
# so the dependency is two-way. eugh.

Cucover::Monkey.extend_every Cucumber::Ast::Scenario       => Cucover::LazyScenario
Cucover::Monkey.extend_every Cucumber::Ast::Background     => Cucover::LazyTestCase
Cucover::Monkey.extend_every Cucumber::Ast::StepInvocation => Cucover::LazyStepInvocation

Before do
  Cucover::Rails.patch_if_necessary
end
