require 'date'

class Payment < Struct.new(:amount, :date)
end

class Transaction
  attr_reader :json

  def initialize(json)
    @json = json
  end

  def amount
    @json['debit']
  end

  def description
    @json['transactionDescription']
  end

  def date
    Date.parse(@json['date'])
  end
end

class Account
  attr_reader :json

  def initialize(cibc, json)
    @id = json['id']
    @json = json
    @cibc = cibc
  end

  def last_pay_transaction
    transactions.select { |t| t.description.include? Cibc::PAY_KEYWORD }.last
  end

  def last_pay_date
    last_pay_transaction.date
  end

  def last_pay_amount
    last_pay_transaction.json['credit']
  end

  def balance
    @json['balance']
  end

  def quicklink
    @json['displayAttributes']['quickLinks']
  end

  def category
    @json['categorization']['category']
  end

  def deposit?
    category == 'DEPOSIT'
  end

  def credit?
    category == 'CREDIT'
  end

  def available_funds
    @json['availableFunds']
  end

  def loan?
    @json['categorization']['subCategory'] == 'LOAN'
  end

  def credit_card?
    @json['categorization']['subCategory'] == 'CREDIT_CARD'
  end

  def last_payment_date
    Date.parse(details['details']['nextPaymentDueDate'])
  end

  def next_payment
    if loan?
      amount = details['details']['nextPayment']['totalAmount']['amount']
      date = Date.parse(details['details']['nextPayment']['paymentDate'])
      return Payment.new(amount, date)
    end
    amount = details['details']['minPaymentDueAmount']&.fetch('amount')
    to_be_posted = details['details']['paymentToBePosted']&.fetch('amount') || 0
    if Date.today - 10 < last_payment_date
      to_be_posted += details['details']['lastPaymentAmount']['amount']
    end
    date_str = details['details']['nextPaymentDueDate']
    date = date_str && Date.parse(date_str)
    if date && amount
      Payment.new(amount - to_be_posted, date)
    end
  end

  def transactions(num_days=30)
    to_date = Date.today
    from_date = to_date - num_days
    limit = 1000
    transactions_json = @cibc.get("/ebm-ai/api/v1/json/transactions?accountId=#{@id}&filterBy=range&fromDate=#{from_date.iso8601}&lastFilterBy=range&limit=#{limit}&offset=0&sortAsc=true&sortByField=date&toDate=#{to_date.iso8601}")
    transactions_json['transactions'].map do |json|
      Transaction.new(json)
    end
  end

  def details
    @cibc.get("/ebm-ai/api/v1/json/accountDetails/#{@id}")['accountDetails']
  end
end
