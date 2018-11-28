# require 'tmpdir'

RSpec.describe Cryptos::Bitcoin do
  let(:to_address) {
    Cryptos::Bitcoin::Address.new Cryptos::PublicKey.new Cryptos::PrivateKey.generate
  }

  before :all do
    @cli = Cryptos::Connectors::Cli.new
    @private_key = Cryptos::PrivateKey.generate
    @public_key = Cryptos::PublicKey.new @private_key
    @from_address = Cryptos::Bitcoin::Address.new @public_key
    @cli.run "importaddress #{@from_address} src", run_mode: :system
    @cli.run "generatetoaddress 105 #{@from_address}", run_mode: :inline
    @utxos = @cli.run "listunspent 1 9999 \"[\\\"#{@from_address}\\\"]\"", v: false
  end

  before do
    @cli.run "importaddress #{to_address} dst", run_mode: :system
  end

  it 'spend coinbase' do
    input = Cryptos::Input.from_utxo @utxos, 0
    output = Cryptos::Output.p2pkh to_address, 100_000_000
    change = Cryptos::Output.p2pkh_change @from_address, input, output

    transaction = Cryptos::Transaction.from_ioc input, output, change
    rawtx = transaction.sign_input 0, @from_address

    @cli.run "sendrawtransaction #{rawtx}", run_mode: :system
    generate_and_check @cli, to_address, '1.00000000'
  end

  describe 'nLocktime' do
    it 'as number of blocks' do
      input = Cryptos::Input.from_utxo @utxos, 1, sequence: 0
      output = Cryptos::Output.p2pkh to_address, 100_000_000
      change = Cryptos::Output.p2pkh_change @from_address, input, output

      locktime = @cli.run("getblockcount").to_i + 1
      transaction = Cryptos::Transaction.from_ioc input, output, change, locktime: locktime
      rawtx = transaction.sign_input 0, @from_address

      result = @cli.run "testmempoolaccept '[\"#{rawtx}\"]'"
      expect(result).to include 'non-final'

      generate_and_check @cli, to_address, '0.00000000'

      @cli.run "sendrawtransaction #{rawtx}", run_mode: :system
      generate_and_check @cli, to_address, '1.00000000'
    end

    it 'as unix timestamp' do
      input = Cryptos::Input.from_utxo @utxos, 2, sequence: 0
      output = Cryptos::Output.p2pkh to_address, 100_000_000
      change = Cryptos::Output.p2pkh_change @from_address, input, output

      transaction = Cryptos::Transaction.from_ioc input, output, change, locktime: Time.now.utc.to_i + 5
      rawtx = transaction.sign_input 0, @from_address

      @cli.run "sendrawtransaction #{rawtx}", run_mode: :system
      generate_and_check @cli, to_address, '0.00000000'

      sleep 6
      generate_and_check @cli, to_address, '1.00000000'
    end
  end
end
