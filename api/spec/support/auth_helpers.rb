# frozen_string_literal: true

# Auth here is a bearer JWT that is never checked against the database —
# AuthorizeApiRequest builds an OpenStruct straight from the claims. Request
# specs therefore only need a correctly signed token whose `scheme` claim
# matches an Organization row.
module AuthHelpers
  # Returns headers for an assessor in the given organization.
  def auth_headers_for(organization, user_id: 1, role: 'admin')
    token = JsonWebToken.encode(
      user_id: user_id,
      role: role,
      scheme: organization.scheme
    )

    { 'Authorization' => "Bearer #{token}", 'Accept' => 'application/json' }
  end

  # A token whose signature is valid but whose scheme matches no Organization.
  def auth_headers_for_unknown_tenant(user_id: 1, role: 'admin')
    token = JsonWebToken.encode(user_id: user_id, role: role, scheme: 'no-such-org')
    { 'Authorization' => "Bearer #{token}", 'Accept' => 'application/json' }
  end

  def json_body
    JSON.parse(response.body)
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
end
