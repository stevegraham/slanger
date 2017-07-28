#encoding: utf-8
require 'spec_helper'

describe Slanger::Api::RequestValidation do
  describe '#socket_id' do
    it 'validation' do
      socket_id = "POST\n/apps/99759/events\nauth_key=840543d97de9803651b1&auth_timestamp=123&auth_version=1.0&body_md5=some_md5&dummy="

      expect {validate(nil)            }.not_to raise_error
      expect {validate("1234.123455")  }.not_to raise_error

      expect {validate(socket_id)      }.to     raise_error Slanger::Api::InvalidRequest
      expect {validate("something 123")}.to     raise_error Slanger::Api::InvalidRequest

      expect {validate("1234.12345 ")               }.to raise_error Slanger::Api::InvalidRequest
      expect {validate(" 1234.12345")               }.to raise_error Slanger::Api::InvalidRequest
      expect {validate("hello\n1234.123456\nhomakov") }.to raise_error Slanger::Api::InvalidRequest
    end
  end

  before do
    request = mock("request")
    request.expects(:authenticate).times(0..2)
    Signature::Request.expects(:new).times(0..2).returns request
  end

  describe "#channels" do
    let(:body) { {socket_id: "1234.5678", channels: channels}.to_json }

    context "with valid channels" do
      let(:channels) { ["MY_CHANNEL", "presence-abcd", "foo-bar_1234@=,.;", "a"*164] }

      it "returns an array of valid channel_id values" do
        rv = Slanger::Api::RequestValidation.new(body, {}, "")

        expect(rv.channels).to eq ["MY_CHANNEL", "presence-abcd", "foo-bar_1234@=,.;", "a"*164]
      end
    end

    context "with invalid characters" do
      let(:channels) { ["MY_CHANNEL:presence-abcd", "presence-abcd"] }

      it "rejects invalid channels" do
        expect{ Slanger::Api::RequestValidation.new(body, {}, "")}.to raise_error Slanger::Api::InvalidRequest
      end
    end

    context "with invalid channel length" do
      let(:channels) { ["a"*165] }

      it "rejects names longer than 164 characters" do
        expect{ Slanger::Api::RequestValidation.new(body, {}, "")}.to raise_error Slanger::Api::InvalidRequest
      end
    end
  end

  describe "#socket_id" do
    it do
      rv = Slanger::Api::RequestValidation.new(body("1234.5678"), {}, "")
      expect(rv.socket_id).to eq "1234.5678"
    end
  end

  def validate(socket_id)
    Slanger::Api::RequestValidation.new(body(socket_id), {}, "").socket_id
  end

  def body(socket_id)
    {socket_id: socket_id}.to_json
  end
end

