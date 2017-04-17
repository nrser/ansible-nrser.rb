#!/usr/bin/env ruby
# WANT_JSON
# ^ i think this is something telling ansible to provide JSON args?

# stdlib
require 'json'
require 'shellwords'
require 'pp'

# deps
require 'nrser'

$warnings = []

def namespace prefix, hash
  Hash[
    hash.map {|key, value|
      ["#{ prefix }_#{ key }", value]
    }
  ]
end

def warn msg, **details
  unless details.empty?
    
  end
  
  $warnings << msg
end

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
    msg = NRSER.squish <<-END
      set_fact_with_ruby failed: #{ e.message } (#{ e.class.name }).
      See #{ path } for details.
    END
    
    formatted = NRSER.format_exception(e)
    
    File.open(path, 'w') {|f|
      f.puts "ERROR:\n\n"
      f.puts NRSER.indent(formatted)
      
      f.puts "\nINPUT:\n\n"
      f.puts NRSER.indent(input) if defined? input
      
      f.puts "\nARGS:\n\n"
      f.puts NRSER.indent(args.pretty_inspect) if defined? args
      
      f.puts "\nRUBY:\n"
      f.puts NRSER.indent("VERSION: #{ RUBY_VERSION }")
      f.puts NRSER.indent("PATH: #{ RbConfig.ruby }")
    }
    
    print JSON.dump({
      'failed' => true,
      'msg' => msg,
      'warnings' => $warnings,
      'exception' => formatted,
    })
  end
end

main if __FILE__ == $0