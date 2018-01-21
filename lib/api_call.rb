require 'typhoeus'

class ApiCall
  def initialize(url_string, method)
    @url = URI('https://www.cibconline.cibc.com' + url_string)
    @method = method
    @headers = {
      'accept-language' => 'en',
      'content-type' => 'application/vnd.api+json',
      'accept' => 'application/vnd.api+json',
      'x-requested-with' => 'XMLHttpRequest',
      'brand' => 'cibc',
      'client-type' => 'default_web',
      'accept-encoding' => 'gzip, deflate, br'
    }
    @body = ''
  end

  def self.get(url_string)
    new(url_string, :get)
  end

  def self.post(url_string)
    new(url_string, :post)
  end

  def body(body_string)
    @body = body_string
    self
  end

  def header(name, value)
    @headers[name] = value
    self
  end

  def token(token_string)
    header('x-auth-token', token_string)
  end

  def get_response_header(header)
    get_response.headers[header]
  end

  def get_response
    @request = Typhoeus::Request.new(@url, method: @method, body: @body, headers: @headers, accept_encoding: 'gzip', followlocation: true)
    @request.run
    @request.response
  end
end
