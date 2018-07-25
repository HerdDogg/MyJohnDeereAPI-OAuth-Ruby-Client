# frozen_string_literal: true

require "byebug"
require "dotenv/load"
require "json"
require "oauth"

JSON_TYPE = "application/vnd.deere.axiom.v3+json"

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
      Accept: JSON_TYPE
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
# rubocop:enable Metrics/AbcSize

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

def get(url)
  return nil unless access_token

  response = access_token.get(
    "#{ENV['JOHN_DEERE_API_URL']}/platform#{url}",
    accept: JSON_TYPE
  )

  response.body
end

def post(url, data)
  return nil unless access_token

  puts "Posting: url[#{url}]; data[#{data}]"

  response = access_token.post(
    "#{ENV['JOHN_DEERE_API_URL']}/platform#{url}",
    data.to_json.to_s,
    accept: JSON_TYPE,
    "content-encoding": JSON_TYPE,
    "content-type": JSON_TYPE
  )

  puts response

  response.body
end

def fetch_user
  puts ""
  puts "User:"
  puts get("/users/herddogg")
  puts ""
end

def fetch_organizations
  puts ""
  puts "Organizations:"
  puts get("/users/herddogg/organizations")
  puts ""
end

# rubocop:disable Metrics/MethodLength, Style/ConditionalAssignment
def fetch_asset_types
  puts ""
  puts "Asset Types:"

  next_url = "/assetCatalog"

  while next_url
    puts "fetching #{next_url}"

    response = JSON.parse(get(next_url))

    puts response

    if response["links"][1]["rel"] == "nextPage"
      next_url = \
        response["links"][1]["uri"]
        .gsub("https://sandboxapi.deere.com/platform", "")
    else
      next_url = nil
    end

    puts ""
  end
end
# rubocop:enable Metrics/MethodLength, Style/ConditionalAssignment

def fetch_assets(org_id)
  puts ""
  puts "Asset [#{org_id}]:"
  puts get("/organizations/#{org_id}/assets")
  puts ""
end

# rubocop:disable Metrics/MethodLength, Style/ConditionalAssignment
def fetch_contribution_definitions
  puts ""
  puts "Contribution Definitions:"
  puts get("/contributionDefinitions")
  puts ""
end
# rubocop:enable Metrics/MethodLength, Style/ConditionalAssignment

def fetch_asset(asset_id)
  puts ""
  puts "Asset [#{asset_id}]:"
  puts get("/assets/#{asset_id}")
  puts ""
end

def create_asset(org_id, title, text)
  puts ""
  puts "Creating asset [#{org_id}][#{title}][#{text}]:"
  puts post(
    "/organizations/#{org_id}/assets",
    {
      text: text,
      title: title,
      assetCategory: "DEVICE",
      assetSubType: "OTHER",
      assetType: "SENSOR"
    }
  )
  puts ""
end

# def create_asset_location(asset_id, lat, lon)
# end

%w[JOHN_DEERE_API_KEY JOHN_DEERE_API_SECRET JOHN_DEERE_API_URL].each do |var|
  unless ENV[var]
    puts "Ensure that #{var} is set in your .env file"
    exit
  end
end

if ENV["JOHN_DEERE_OAUTH_SECRET"] && ENV["JOHN_DEERE_OAUTH_TOKEN"]
  # fetch_user
  # fetch_organizations
  # fetch_asset_types
  # fetch_assets("372446")
  # fetch_asset("7e7a04a9-4c4f-4773-95a4-ce1cbcfd62bb")
  # fetch_contribution_definitions
  create_asset("372446", "EXAMPLE_TITLE", "EXAMPLE_TEXT")
else
  fetch_access_token
end
