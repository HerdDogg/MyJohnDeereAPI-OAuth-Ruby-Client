# frozen_string_literal: true

require "byebug"
require "dotenv/load"
require "json"
require "oauth"

def get_basic_catalog(token = nil)
  oauth_consumer.request(
    :get,
    "https://sandboxapi.deere.com/platform/",
    token,
    {},
    "accept" => "application/vnd.deere.axiom.v3+json"
  )
end

def oauth_consumer(options = {})
  OAuth::Consumer.new(
    ENV["JOHN_DEERE_API_KEY"],
    ENV["JOHN_DEERE_API_SECRET"],
    options
  )
end

# rubocop:disable Metrics/MethodLength
def setup_links_for_oauth(catalog)
  (JSON.parse(catalog.body)["links"]).each do |map|
    case map["rel"]
    when "oauthRequestToken" then
      @request_token_uri = map["uri"]
    when "oauthAuthorizeRequestToken" then
      @authorize_request_token_uri = map["uri"]
    when "oauthAccessToken" then
      @access_token_uri = map["uri"]
    when "files" then
      @files_uri = map["uri"]
    when "currentUser" then
      @current_user_uri = map["uri"]
    end
  end

  @authorize_request_token_uri.sub!("?oauth_token={token}", "")
end
# rubocop:enable Metrics/MethodLength

def oauth_params
  {
    site: "https://sandboxapi.deere.com",
    header: {
      Accept: "application/vnd.deere.axiom.v3+json"
    },
    http_method: :get,
    request_token_url: @request_token_uri,
    access_token_url: @access_token_uri,
    authorize_url: @authorize_request_token_uri
  }
end

setup_links_for_oauth(get_basic_catalog)

# puts @current_user_uri

puts ""
puts "***** Fetching request token *****"

request_token = oauth_consumer(oauth_params).get_request_token({}, "oob")
puts "Request Token received - #{request_token.token}"
puts ""
puts "---> Goto to url mentioned below to authorize."
puts "---> Then paste the access token verifier"
puts request_token.authorize_url

verifier = gets.chomp

puts
puts
puts "***** Fetching access token *****"

access_token = request_token.get_access_token(oauth_verifier: verifier)
puts "Access token received - #{access_token.token}"
puts
puts "***** Fetching user details: GET /users/{userName} *****"

response = access_token.get(
  "/platform/users/herddogg/organizations",
  "accept" => "application/vnd.deere.axiom.v3+json"
)
puts
puts "JSON Response"
puts response.body

setup_links_for_oauth(get_basic_catalog(access_token))
