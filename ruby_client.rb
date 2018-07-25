# frozen_string_literal: true

require "byebug"
require "dotenv/load"
require "json"
require "oauth"

def get_basic_catalog(token = nil)
  oauth_consumer.request(
    :get,
    "#{ENV['JOHN_DEERE_API_URL']}/platform/",
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
    site: ENV["JOHN_DEERE_API_URL"],
    header: {
      Accept: "application/vnd.deere.axiom.v3+json"
    },
    http_method: :get,
    request_token_url: @request_token_uri,
    access_token_url: @access_token_uri,
    authorize_url: @authorize_request_token_uri
  }
end

# rubocop:disable Metrics/AbcSize
def fetch_access_token
  setup_links_for_oauth(get_basic_catalog)

  request_token = oauth_consumer(oauth_params).get_request_token({}, "oob")

  puts "Visit this link in your browser and paste the 6 digit code here:"
  puts request_token.authorize_url

  verifier = gets.chomp

  new_access_token = request_token.get_access_token(oauth_verifier: verifier)

  puts ""
  puts "Paste this into your .env file:"
  puts "JOHN_DEERE_OAUTH_SECRET=#{new_access_token.secret}"
  puts "JOHN_DEERE_OAUTH_TOKEN=#{new_access_token.token}"
end

def access_token
  return nil unless existing_access_token?

  @access_token ||= OAuth::AccessToken.new(
    oauth_consumer,
    ENV["JOHN_DEERE_OAUTH_TOKEN"],
    ENV["JOHN_DEERE_OAUTH_SECRET"]
  )
end

def existing_access_token?
  ENV["JOHN_DEERE_OAUTH_SECRET"] && ENV["JOHN_DEERE_OAUTH_TOKEN"]
end

def fetch_url(url, options = { method: :get })
  return nil unless access_token

  response = access_token.send(
    options[:method],
    "#{ENV['JOHN_DEERE_API_URL']}/platform#{url}",
    accept: "application/vnd.deere.axiom.v3+json"
  )

  puts response.body
end
# rubocop:enable Metrics/AbcSize

%w[JOHN_DEERE_API_KEY JOHN_DEERE_API_SECRET JOHN_DEERE_API_URL].each do |var|
  unless ENV[var]
    puts "Ensure that #{var} is set in your .env file"
    exit
  end
end

if ENV["JOHN_DEERE_OAUTH_SECRET"] && ENV["JOHN_DEERE_OAUTH_TOKEN"]
  fetch_url(
    "/users/herddogg/organizations",
    method: :get
  )
else
  fetch_access_token
end
