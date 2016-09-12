require 'json'
require 'signet/oauth_2/client'

# Because google-auth-library-ruby is shit.
class ServiceAccountCredentials < Signet::OAuth2::Client
  TOKEN_CRED_URI = 'https://www.googleapis.com/oauth2/v3/token'.freeze

  def initialize(options = {})
    json_key_file, scope, person = options.values_at(:json_key_file, :scope, :person)
    file = File.read(json_key_file)
    data_hash = JSON.parse(file)
    private_key = data_hash['private_key']
    client_email = data_hash['client_email']
    super(token_credential_uri: TOKEN_CRED_URI,
          audience: TOKEN_CRED_URI,
          scope: scope,
          issuer: client_email,
          person: person,
          signing_key: OpenSSL::PKey::RSA.new(private_key))
  end
end
