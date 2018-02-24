#!/usr/bin/env ruby
# WANT_JSON
# ^ i think this is something telling ansible to provide JSON args?

# stdlib
require 'json'
require 'shellwords'
require 'pp'

# deps
require 'nrser'

def namespace prefix, hash
  Hash[
    hash.map {|key, value|
      ["#{ prefix }_#{ key }", value]
    }
  ]
end

def main
  input = nil
  args = nil
  changed = false

  begin
    input = File.read ARGV[0]
    args = JSON.load input
    
    b = binding
    
    ['bind', 'vars'].each do |key|
      if args.key? key
        args[key].each {|k, v|
          b.local_variable_set k, v
        }
      end
    end
    
    if args['src'] && args['file']
      raise "Don't provide both src and file!"
    end
    
    if !args['src'] && !args['file']
      raise "Must provide one of src or file!"
    end
    
    src = args['src'] || File.read( args['file'] )
    result = b.eval src
    
    if result.is_a? Hash
      result = namespace(args['namespace'], result) if args['namespace']
    else
      result = {'result' => result}
    end

    print JSON.dump({
      'changed' => changed,
      'ansible_facts' => result,
    })
    
  rescue Exception => e
    path = File.join Dir.pwd, "ansible-error.log"
    msg = NRSER.squish <<-END
      vars.rb failed: #{ e.message } (#{ e.class.name }).
      See #{ path } for details.
    END
    
    File.open(path, 'w') {|f|
      f.puts "ERROR:\n\n"
      f.puts NRSER.indent(NRSER.format_exception(e))
      
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
    })
  end
end

main if __FILE__ == $0
