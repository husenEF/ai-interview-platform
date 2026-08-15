# frozen_string_literal: true

require 'webmock/rspec'

# No spec may reach the network. The scoring path is tested against timeouts,
# rate limits, malformed JSON and null levels — all of which have to be
# deterministic, and none of which should cost a Gemini API call.
#
# A spec that forgets to stub Gemini fails with WebMock::NetConnectNotAllowedError
# naming the exact URL, which is the behaviour we want: loud, not silently live.
WebMock.disable_net_connect!(allow_localhost: false)

module GeminiStubs
  GENERATE_CONTENT_URL = %r{generativelanguage\.googleapis\.com/.*:generateContent}

  # Gemini's REST response nests the model's JSON payload inside
  # candidates[0].content.parts[0].text, and Gemini::HttpClient#parse_response
  # strips markdown fences before parsing it. Stubs must mirror that shape or
  # they test a response the client never actually sees.
  def stub_gemini_returning(payload, status: 200)
    body = {
      candidates: [
        { content: { parts: [{ text: payload.is_a?(String) ? payload : payload.to_json }] } }
      ]
    }.to_json

    stub_request(:post, GENERATE_CONTENT_URL)
      .to_return(status: status, body: body, headers: { 'Content-Type' => 'application/json' })
  end

  def stub_gemini_timing_out
    stub_request(:post, GENERATE_CONTENT_URL).to_timeout
  end

  def stub_gemini_erroring(status)
    stub_request(:post, GENERATE_CONTENT_URL)
      .to_return(status: status, body: { error: { message: "upstream #{status}" } }.to_json,
                 headers: { 'Content-Type' => 'application/json' })
  end
end

RSpec.configure do |config|
  config.include GeminiStubs
end
