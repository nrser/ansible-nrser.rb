#!/usr/bin/env ruby
# 
# 
# 
 
# WANT_JSON
# ^ tell Ansible to provide args as JSON encoded file.

# stdlib
require 'json'
require 'shellwords'
require 'pp'

# Global var to append warning messages to.
$warnings = []

# Add a warning to $warnings to be sent back to Ansible and displayed to the
# user.
def warn msg, **details
  unless details.empty?
    msg += ", details: " + details.pretty_inspect
  end
  
  $warnings << msg
end


# Entry point
def main
  input = nil
  args = nil

  begin
    input = File.read ARGV[0]
    
    args = JSON.load input
    
    var_name = args.fetch 'var_name'
    
    b = binding
    
    ['bind', 'vars'].each do |key|
      if args.key? key
        warn "#{ key }: #{ args[key].inspect }"
        args[key].each {|k, v|
          b.local_variable_set k, v
        }
      end
    end
    
    result = b.eval args.fetch('src')

    print JSON.dump({
      'changed' => false,
      'ansible_facts' => {
        var_name => result,
      },
      'warnings' => $warnings,
    })
    
  rescue Exception => e
    path = File.join Dir.pwd, "ansible-error.log"
    msg = "set_fact_with_ruby failed: #{ e.message } (#{ e.class.name }). " +
          "See #{ path } for details."
    
    formatted = \
      "#{ e.message } (#{ e.class }):\n  #{ e.backtrace.join("\n  ") }"
    
    indent = ->(str) { str.gsub(/^/, '  ') }
    
    File.open(path, 'w') {|f|
      f.puts "ERROR:\n\n"
      f.puts indent.(formatted)
      
      f.puts "\nINPUT:\n\n"
      f.puts indent.(input) if defined? input
      
      f.puts "\nARGS:\n\n"
      f.puts indent.(args.pretty_inspect) if defined? args
      
      f.puts "\nRUBY:\n"
      f.puts indent.("VERSION: #{ RUBY_VERSION }")
      f.puts indent.("PATH: #{ RbConfig.ruby }")
      
      f.puts "\nENV:\n"
      ENV.sort.each {|name, value|
        f.puts indent.("#{ name }: #{ value.inspect }")
      }
    }
    
    print JSON.dump({
      'failed' => true,
      'msg' => msg,
      'warnings' => $warnings,
      'exception' => formatted,
    })
  end
end # main

# Execute when run as executable
main if __FILE__ == $0
