require 'rubygems'
require 'autotest'
require File.join(File.dirname(__FILE__), 'result')

##
# Autotest::Growl
#
# == FEATUERS:
# * Display autotest results as local or remote Growl notifications.
# * Clean the terminal on every test cycle while maintaining scrollback.
#
# == SYNOPSIS:
# ~/.autotest
#   require 'autotest/growl'
module Autotest::Growl

  GEM_PATH = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))

  @label = ''
  @modified_files = []
  @ran_tests = false
  @ran_features = false

  @@remote_notification = false
  @@one_notification_per_run = false
  @@clear_terminal = true
  @@hide_label = false
  @@show_modified_files = false
  @@image_dir = File.join(GEM_PATH, 'img')

  ##
  # Whether to use remote or local notificaton (default).
  def self.remote_notification=(boolean)
    @@remote_notification = boolean
  end

  ##
  # Whether to limit the number of notifications per run to one or not (default).
  def self.one_notification_per_run=(boolean)
    @@one_notification_per_run = boolean
  end

  ##
  # Whether to clear the terminal before running tests (default) or not.
  def self.clear_terminal=(boolean)
    @@clear_terminal = boolean
  end

  ##
  # Whether to display the label (default) or not.
  def self.hide_label=(boolean)
    @@hide_label = boolean
  end

  ##
  # Whether to display the modified files or not (default).
  def self.show_modified_files=(boolean)
    @@show_modified_files = boolean
  end

  ##
  # Directory where notification icons can be found
  def self.image_dir=(path)
    @@image_dir = path
  end

  ##
  # Display a message through Growl.
  def self.growl(title, message, icon, priority=0, stick="")
    growl = File.join(GEM_PATH, 'growl', 'growlnotify')
    image = File.join(@@image_dir, "#{icon}.png")
    case RUBY_PLATFORM
    when /mswin/
      growl += '.com'
      system %(#{growl} #{message.inspect} /a:"Autotest" /r:"Autotest" /n:"Autotest" /i:"#{image}" /p:#{priority} /t:"#{title}")
    when /darwin/
      options = "-w -n Autotest --image '#{image}' -p #{priority} -m '#{message}' '#{title}' #{stick}"
      options << " -H localhost" if @@remote_notification
      system %(#{growl} #{options} &)
    else
      raise "#{RUBY_PLATFORM} is not supported by autotest-growl" 
    end
  end

  ##
  # Display the modified files.
  Autotest.add_hook :updated do |autotest, modified|
    @ran_tests = @ran_features = false
    if @@show_modified_files
      if modified != @last_modified
        growl @label + 'Modifications detected.', modified.collect {|m| m[0]}.join(', '), 'info', 0
        @last_modified = modified
      end
    end
    false
  end

  ##
  # Set the label and clear the terminal.
  Autotest.add_hook :run_command do
    @label = File.basename(Dir.pwd).upcase + ': ' if !@@hide_label
    print "\n"*2 + '-'*80 + "\n"*2
    print "\e[2J\e[f" if @@clear_terminal
    false
  end

  ##
  # Parse the RSpec and Test::Unit results and send them to Growl.
  Autotest.add_hook :ran_command do |autotest|
    unless @@one_notification_per_run && @ran_tests
      result = Result.new(autotest)
      if result.exists?
        case result.framework
        when 'test-unit'        
          if result.has?('test-error')
            growl @label + 'Cannot run some unit tests.', "#{result.get('test-error')} in #{result.get('test')}", 'error', 2
          elsif result.has?('test-failed')
            growl @label + 'Some unit tests failed.', "#{result['test-failed']} of #{result.get('test-assertion')} in #{result.get('test')} failed", 'failed', 2
          else
            growl @label + 'All unit tests passed.', "#{result.get('test-assertion')} in #{result.get('test')}", 'passed', -2
          end
        when 'rspec'
          if result.has?('example-failed')
            growl @label + 'Some RSpec examples failed.', "#{result['example-failed']} of #{result.get('example')} failed", 'failed', 2
          elsif result.has?('example-pending')
            growl @label + 'Some RSpec examples are pending.', "#{result['example-pending']} of #{result.get('example')} pending", 'pending', -1
          else
            growl @label + 'All RSpec examples passed.', "#{result.get('example')}", 'passed', -2
          end
        end
      else
        growl @label + 'Could not run tests.', '', 'error', 2
      end
      @ran_tests = true
    end
    false
  end

  ##
  # Parse the Cucumber results and sent them to Growl.
  Autotest.add_hook :ran_features do |autotest|
    unless @@one_notification_per_run && @ran_features
      result = Result.new(autotest)
      if result.exists?
        case result.framework
        when 'cucumber'
          explanation = []
          if result.has?('scenario-undefined') || result.has?('step-undefined')
            explanation << "#{result['scenario-undefined']} of #{result.get('scenario')} not defined" if result['scenario-undefined']
            explanation << "#{result['step-undefined']} of #{result.get('step')} not defined" if result['step-undefined']
            growl @label + 'Some Cucumber scenarios are not defined.', "#{explanation.join("\n")}", 'pending', -1          
          elsif result.has?('scenario-failed') || result.has?('step-failed')
            explanation << "#{result['scenario-failed']} of #{result.get('scenario')} failed" if result['scenario-failed']
            explanation << "#{result['step-failed']} of #{result.get('step')} failed" if result['step-failed']
            growl @label + 'Some Cucumber scenarios failed.', "#{explanation.join("\n")}", 'failed', 2
          elsif result.has?('scenario-pending') || result.has?('step-pending')
            explanation << "#{result['scenario-pending']} of #{result.get('scenario')} pending" if result['scenario-pending']
            explanation << "#{result['step-pending']} of #{result.get('step')} pending" if result['step-pending']
            growl @label + 'Some Cucumber scenarios are pending.', "#{explanation.join("\n")}", 'pending', -1          
          else
            growl @label + 'All Cucumber features passed.', '', 'passed', -2
          end      
        end
      else
        growl @label + 'Could not run features.', '', 'error', 2
      end
      @ran_features = true
    end
    false
  end

end
