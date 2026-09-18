module Delivery
  class Error < StandardError; end

  def self.post(url, payload)
    response = Net::HTTP.post(URI(url), payload.to_json, "Content-Type" => "application/json")
    raise Error, "#{response.code} #{response.body&.byteslice(0, 200)}" unless response.is_a?(Net::HTTPSuccess)
  rescue SystemCallError, SocketError, Net::OpenTimeout, Net::ReadTimeout => e
    raise Error, e.message
  end
end
