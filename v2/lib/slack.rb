require "json"
require "net/http"

require "yake"

require_relative "reddit/post"

class Hash
  def symbolize_names() JSON.parse to_json, symbolize_names: true end
end

handler :post do |event|
  uri     = URI event["WEBHOOK_URL"]
  post    = Reddit::Post.new event["DATA"].symbolize_names
  headers = {
    "authorization" => "Bearer #{ event["ACCESS_TOKEN"] }",
    "content-type"  => "application/json; charset=utf-8"
  }
  res  = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
    req = Net::HTTP::Post.new(uri.path, **headers)
    req.body = post.to_slack.to_json
    http.request req
  end

  {
    statusCode: res.code,
    body:       res.body,
    headers:    res.each_header.sort.to_h,
  }
end

handler :migrate do
  require "aws-sdk-dynamodb"
  require "aws-sdk-s3"
  require_relative "slack/auth"
  bucket   = Aws::S3::Bucket.new name: "brutalismbot"
  dynamodb = Aws::DynamoDB::Client.new
  bucket.objects(prefix: "data/v1/auths/").map do |obj|
    Yake.logger.info "GET s3://#{ bucket.name }/#{ obj.key }"
    Slack::Auth.new JSON.parse obj.get.body.read do |auth|
      auth.created_utc = obj.last_modified.iso8601
    end
  end.map do |auth|
    {
      put: {
        table_name: "Brutalismbot",
        item: {
          GUID:         File.join(auth.team_id, auth.channel_id),
          SORT:         "SLACK/AUTH",
          CREATED_UTC:  auth.created_utc || Time.now.utc.iso8601,
          ACCESS_TOKEN: auth.access_token,
          TEAM_ID:      auth.team_id,
          TEAM_NAME:    auth.team_name,
          CHANNEL_ID:   auth.channel_id,
          CHANNEL_NAME: auth.channel_name,
          SCOPE:        auth.scope,
          WEBHOOK_URL:  auth.url.to_s,
          JSON:         auth.to_json,
        }.compact
      }
    }
  end.each_slice(25) do |page|
    page.each { |x| Yake.logger.info "PUT #{ x.dig(:put, :item).slice :GUID, :SORT }"}
    dynamodb.transact_write_items transact_items: page
  end
end
