#encoding: utf-8
require 'spec_helper'

describe Slanger::Api::RequestValidation do
  describe '#socket_id' do
    it 'validation' do
      socket_id = "POST\n/apps/99759/events\nauth_key=840543d97de9803651b1&auth_timestamp=123&auth_version=1.0&body_md5=some_md5&dummy="

      expect {validate(nil)      }.not_to     raise_error Signature::AuthenticationError
      expect {validate(socket_id)      }.to     raise_error Signature::AuthenticationError
      expect {validate("something 123")}.to     raise_error Signature::AuthenticationError
      expect {validate("335e6070-96fc-4950-a94a-a9032d85ae26")                }.not_to raise_error Signature::AuthenticationError

      expect {validate("335e6070-96fc-4950-a94a-a9032d85ae26 ")               }.to raise_error Signature::AuthenticationError
      expect {validate(" 335e6070-96fc-4950-a94a-a9032d85ae26")               }.to raise_error Signature::AuthenticationError
      expect {validate("hello\n35e6070-96fc-4950-a94a-a9032d85ae26\nhomakov") }.to raise_error Signature::AuthenticationError
      expect {validate("35e6070-96fc-4950-a94a-a9032d85ae26")                 }.to raise_error Signature::AuthenticationError
      expect {validate("335e6070-96fc-4950-a94aa9032d85ae26")                 }.to raise_error Signature::AuthenticationError
    end
  end

  def validate(socket_id)
    Slanger::Api::RequestValidation.new(body(socket_id)).socket_id
  end

  def body(socket_id)
    {socket_id: socket_id}.to_json
  end

end

