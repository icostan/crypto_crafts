module Cryptos
  module Connectors
    class Cli
      attr_reader :program, :network, :verbose

      def initialize(program: 'bitcoin-cli', network: 'regtest', verbose: false)
        @program = program
        @network = network
        @verbose = verbose
      end

      def run(args, run_mode: :inline, v: false)
        cmd = "#{program} -#{network} #{args}"
        puts "==> #{cmd}" if v || verbose
        case run_mode
        when :inline
          output = `#{cmd}`
          puts output if v || verbose
          output
        when :system
          success = system cmd
          fail "failed command: #{args}" unless success
          success
        when :daemon
          pid = spawn cmd
          sleep (ENV['BOOTSTRAP'] || 10).to_i
          pid
        else
          raise "dont know how to run #{run_mode}"
        end
      end
    end
  end
end