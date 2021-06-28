require "base64"
require "json"
require "time"

class Hash
  def encode64() to_json.encode64 end
  def symbolize_names() JSON.parse to_json, symbolize_names: true end
  def to_form() URI.encode_www_form(self) end
end

class Integer
  def days() hours * 24 end
  def hours() minutes * 60 end
  def minutes() seconds * 60 end
  def seconds() self end
  def utc() UTC.at(self) end
end

class String
  def camel_case() split(/_/).map(&:capitalize).join end
  def decode64() Base64.strict_decode64(self) end
  def encode64() Base64.strict_encode64(self) end
  def snake_case() gsub(/([a-z])([A-Z])/, '\1_\2').downcase end
  def to_h_from_json(**params) JSON.parse(self, **params) end
  def to_h_from_form() URI.decode_www_form(self).to_h end
end

class Symbol
  def camel_case() to_s.camel_case.to_sym end
  def snake_case() to_s.snake_case.to_sym end
end

class UTC < Time
  def self.at(...) super.utc end
  def self.now() super.utc end
end
