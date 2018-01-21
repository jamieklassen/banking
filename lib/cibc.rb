require 'openssl'
require 'json'
require 'net/http'

CARD_NUMBER = ENV['CARD_NUMBER']
PASSWORD = ENV['PASSWORD']

require_relative 'api_call'
require_relative 'account'

class Cibc
  PAY_KEYWORD = 'PAY CRTXMLDAT CGI'

  def accounts
    @accounts ||= get_accounts
  end

  def find_transactions(substring)
    pay_account.transactions.select do |transaction|
      transaction.description.include? substring
    end
  end

  def get_accounts
    get('/ebm-ai/api/v2/json/accounts')['accounts'].map do |json|
      Account.new(self, json)
    end
  end

  def next_paycheck_date(pay_periods)
    pay_account.last_pay_date + 14 * pay_periods
  end

  def pay_account
    accounts.find do |account|
      account.deposit? && account.transactions.any? do |transaction|
        transaction.description.include? PAY_KEYWORD
      end
    end
  end

  def savings_account
    accounts.find do |account|
      account.quicklink.include? 'SAVING'
    end
  end

  def payments_before_paycheck(pay_periods)
    payments.select { |p| p.date < next_paycheck_date(pay_periods) }
  end

  def next_intact_payment
    prev_intact = pay_account.transactions.find do |transaction|
      transaction.description.include? 'INTACT'
    end
    Payment.new(prev_intact.amount, prev_intact.date + 30)
  end

  def next_rent_payment
    prev_rent = pay_account.transactions.find do |transaction|
      transaction.amount == 1500
    end
    Payment.new(prev_rent.amount, prev_rent.date + 28)
  end

  def amount_due_before_next_paycheck(pay_periods)
    payments_before_paycheck(pay_periods).map(&:amount).sum
  end

  def projected_change(pay_periods)
    pay_account.last_pay_amount * (pay_periods - 1) - amount_due_before_next_paycheck(pay_periods)
  end

  def net_balance(pay_periods=1)
    pay_account.balance + projected_change(pay_periods)
  end

  def net_available_funds(pay_periods=1)
    gross_available_funds + projected_change(pay_periods)
  end

  def payments
    accounts.select(&:credit?).map(&:next_payment).compact <<
      next_intact_payment <<
      next_rent_payment
  end

  def gross_available_funds
    pay_account.available_funds
  end

  def net_worth
    accounts.map do |account|
      account.deposit? ? account.balance : -account.balance
    end.sum
  end

  def get(path)
    body = ApiCall.get(path).token(token).get_response.body
    JSON.load(body)
  end

  def token
    @token ||= fetch_token
  end
  
  def fetch_token
    ApiCall.post('/ebm-anp/api/v1/json/sessions').
      header('www-authenticate', 'CardAndPassword').
      body({
        'card' => {
          'value' => CARD_NUMBER,
          'description' => '',
          'encrypted'=> false,
          'encrypt' => true
        },
        'password' => PASSWORD
      }.to_json).
      get_response_header('x-auth-token')
  end
end
