require 'rubygems'
require 'sequel'
require 'sinatra'
require 'json'
require 'ipaddr'

NEW_RELIC_IP = IPAddr.new("50.31.164.0/24")

configure do
  set :root, File.dirname(__FILE__)
  set :public_folder, Proc.new { File.join(root, "static") }
  DB = Sequel.connect(ENV['DATABASE_URL'] || 'postgres://localhost/webhooks')
end

require './deployment'
require './alert'

helpers do
  def protected!
    return if http_authorized? || ip_whitelisted?
    headers['WWW-Authenticate'] = 'Basic realm="Restricted Area"'
    halt 401, "Not authorized\n"
  end

  def http_authorized?
    auth ||=  Rack::Auth::Basic::Request.new(request.env)
    auth.provided? and auth.basic? and auth.credentials and auth.credentials ==
      [ENV['HTTP_AUTH_USER'] || 'fooooo', ENV["HTTP_AUTH_PASSWORD"] || 'baaaaaar']
  end

  def ip_whitelisted?
    request.ip == "127.0.0.1" || NEW_RELIC_IP.include?(IPAddr.new(request.ip))
  end
end

get '/' do
  protected!
  @deployments = Deployment.order(:created_at.desc)
  @alerts = Alert.order(:created_at.desc)
  erb :index
end

post '/webhook' do
  protected!
  if params[:deployment]
    deployment = Deployment.new(JSON.parse(params[:deployment]))
    deployment.save
  end
  if params[:alert]
    alert = Alert.new(JSON.parse(params[:alert]))
    alert.save
  end
  status 200
end
