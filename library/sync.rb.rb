#!/usr/bin/env ruby
# WANT_JSON
# ^ i think this is something telling ansible to provide JSON args?

require 'json'
require 'shellwords'
require 'pp'

def main
  input = nil
  args = nil
  changed = false

  begin
    input = File.read ARGV[0]
    args = JSON.load input

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