require 'vcr'
require_relative '../lib/cibc'

VCR.configure do |config|
  config.cassette_library_dir = "fixtures/vcr_cassettes"
  config.hook_into :typhoeus
end

describe Cibc do
  describe '#get_accounts' do
    it 'gets accounts' do
      VCR.use_cassette('accounts', :record => :new_episodes) do
        # puts subject.accounts.select(&:credit_card?).map(&:details)
        # p subject.net_available_funds
        p subject.find_transactions('PIZZA')
        # types = subject.pay_account.transactions.map { |t| t.json['transactionType'] }.compact.uniq
        # p subject.pay_account.transactions.select { |tr| tr.json['transactionType'] == 'TG014' }.sort_by(&:date).map(&:amount)
        # p types.map { |t| [t, subject.pay_account.transactions.select { |tr| tr.json['transactionType'] == t }.map(&:description)] }
      end
    end
  end
end
