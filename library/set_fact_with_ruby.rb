#!/usr/bin/env ruby
# 
# 
# 
 
# WANT_JSON
# ^ tell Ansible to provide args as JSON encoded file.

# init bundler in dev env
if ENV['QB_DEV_ENV']
  ENV.each {|k, v|
    if k.start_with? 'QB_DEV_ENV_'
      ENV[k.sub('QB_DEV_ENV_', '')] = v
    end
  }
  require 'bundler/setup'
end

# stdlib
require 'json'
require 'shellwords'
require 'pp'

# We originally used the name 'vars', but switched to prefer 'bind'.
# However, we still support either, but doesn't make sense to provide
# both.
BIND_ARG_NAMES = ['bind', 'vars']

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
    
    b = binding
    
    if BIND_ARG_NAMES.count {|name| args.key? name } > 1
      raise ArgumentError,
            "Please provide exactly one of args #{ BIND_ARG_NAMES.join ', ' }"
    end
    
    BIND_ARG_NAMES.each do |key|
      if args.key? key
        args[key].each {|k, v|
          # Ansible sends null/None values as empty strings, so convert those
          # to nil. This does prevent passing the empty string as a value, but
          # it seems like a more reasonable / intuitive way to treat it.
          v = nil if v == ''
          b.local_variable_set k, v
        }
      end
    end
    
    result = b.eval args.fetch('src')
    
    ansible_facts = if args.key? 'var_name'
      # We received a var_name, so we consider the result to be it's value
      {args['var_name'] => result}
    else
      # The result should be a hash of variable names to value to set
      unless result.is_a? Hash
        raise "When var_name arg is not provided, result of evaluation must "
              "be a Hash of variable names to value to set. " +
              "Found #{ result.inspect }"
      end
      result
    end

    print JSON.dump({
      'changed' => false,
      'ansible_facts' => ansible_facts,
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
