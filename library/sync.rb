#!/usr/bin/env ruby
# WANT JSON
# ^ i think this is something telling ansible to provide JSON args?

require 'json'
require 'shellwords'
require 'pp'

MODULE_COMPLEX_ARGS = "<<INCLUDE_ANSIBLE_MODULE_COMPLEX_ARGS>>"

def parse input
  parsed = {}
  Shellwords.split(input).each do |word|
    (key, value) = word.split('=', 2)
    parsed[key] = value
  end
  unless MODULE_COMPLEX_ARGS.empty?
    parsed.update JSON.load(MODULE_COMPLEX_ARGS)
  end
  parsed
end

def main
  input = nil
  args = nil
  changed = false

  begin
    input = File.read ARGV[0]
    args = parse input

    eval <<-END
      def in_sync?
        #{ args['pre'] || '' }
        #{ args['in_sync?'] }
      end
    END
    
    eval <<-END
      def sync
        #{ args['pre'] || '' }
        #{ args['sync'] }
      end
    END
    
    unless in_sync?
      sync
      changed = true
    end

    print JSON.dump({
      'changed' => changed,
    })
  rescue Exception => e
    print JSON.dump({
      'failed' => true,
      'msg' => e,
      # 'input' => input,
      'args' => args,
      # 'ARGV' => ARGV,
      # 'ruby' => RUBY_VERSION,
    })
  end
end

main if __FILE__ == $0