#!/usr/bin/env ruby
# WANT_JSON
# ^ i think this is something telling ansible to provide JSON args?

require 'json'
require 'shellwords'
require 'pp'

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
    
    if args.key? 'vars'    
      args['vars'].each {|k, v|
        b.local_variable_set k, v
      }
    end
    
    result = b.eval args['src']
    
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
    raise e
    
    print JSON.dump({
      'failed' => true,
      'msg' => e,
      # 'input' => input,
      # 'args' => args,
      # 'ARGV' => ARGV,
      # 'ruby' => RUBY_VERSION,
    })
  end
end

main if __FILE__ == $0