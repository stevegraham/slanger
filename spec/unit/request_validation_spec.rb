#encoding: utf-8
require 'spec_helper'

describe Slanger::Api::RequestValidation do
  describe '#socket_id' do
    Slanger::Validate #force autoload

    it 'validation' do
      socket_id = "POST\n/apps/99759/events\nauth_key=840543d97de9803651b1&auth_timestamp=123&auth_version=1.0&body_md5=some_md5&dummy="

      expect {validate(nil)            }.not_to     raise_error Slanger::Api::InvalidRequest
      expect {validate("1234.123455")  }.not_to raise_error Slanger::Api::InvalidRequest

      expect {validate(socket_id)      }.to     raise_error Slanger::Api::InvalidRequest
      expect {validate("something 123")}.to     raise_error Slanger::Api::InvalidRequest

      expect {validate("1234.12345 ")               }.to raise_error Slanger::Api::InvalidRequest
      expect {validate(" 1234.12345")               }.to raise_error Slanger::Api::InvalidRequest
      expect {validate("hello\n1234.123456\nhomakov") }.to raise_error Slanger::Api::InvalidRequest
    end
  end

  def validate(socket_id)
    Slanger::Api::RequestValidation.new(body(socket_id)).socket_id
  end

  def body(socket_id)
    {socket_id: socket_id}.to_json
  end
end

