#!/usr/bin/env ruby

require 'base64'
require 'httparty'
require 'json'
require 'json/jwt'
require 'pry'
require 'sinatra/base'
require 'sinatra/json'

TRANSLATIONS = {
  # https://tools.ietf.org/html/rfc7517
  kty: 'Key Type',
  alg: 'Algorithm',
  kid: 'Key ID',
  use: 'Public Key Use',
  e: 'Exponent',
  n: 'Modulus',
  # https://tools.ietf.org/html/rfc7519#section-4.1
  iss: 'Issuer',
  sub: 'Subject',
  aud: 'Audience',
  exp: 'Expiration Time',
  nbf: 'Not Before',
  iat: 'Issued At',
  jti: 'JWT ID',
  # https://developer.okta.com/docs/reference/api/oidc/#reserved-claims-in-the-payload-section
  cid: 'Client ID',
  uid: 'User ID',
  ver: 'Version',
  scp: 'Scopes'
}

class App < Sinatra::Base
  def initialize(*args)
    super
    @jwks = {}
  end

  get '/' do
    env = request.env
    token = env['HTTP_AUTHORIZATION'] =~ /^Bearer (.*)/ && $1
    return [404, ['Token not found']] unless token

    header, payload = token.split('.').first(2).map do |encoded|
      JSON.parse(Base64.decode64(encoded))
    end

    json(
      user: {
        email: env['HTTP_X_FORWARDED_EMAIL'],
        username: env['HTTP_X_FORWARDED_PREFERRED_USERNAME'],
      },
      token: {
        header: describe(header),
        payload: describe(payload),
        verification: verify(token, header, payload)
      },
      headers: env.each_with_object({}) do |(k, v), acc|
        next unless match = k.match(/^HTTP_(.*)/)

        acc[match[1]] = v
      end,
      params: params
    )
  end

  def verify(token, header, payload)
    jwk = lookup_key(header, payload)

    {
      jwk: describe(jwk),
      verified: JSON::JWT.decode(token, jwk.to_key) == payload
    }
  rescue => e
    {
      error: e,
      from: e.backtrace.first
    }
  end

  def lookup_key(header, payload)
    id = header.fetch('kid')
    return @jwks[id] if @jwks.key?(id)

    logger.info("Fetching key #{id}")
    @jwks[id] = fetch_key(id, payload)
  end

  def fetch_key(id, payload)
    issuer    = payload.fetch('iss')
    client_id = payload.fetch('cid')

    meta = HTTParty.get(
      "#{issuer}/.well-known/oauth-authorization-server",
      headers: { 'Content-Type' => 'application/json' },
      query: { client_id: client_id }
    )

    keys = HTTParty.get(
      meta.fetch('jwks_uri'),
      headers: { 'Content-Type' => 'application/json' },
    ).fetch('keys')

    key = keys.find { |k| k['kid'] == id } || raise("Could not find key")

    JSON::JWK.new(key)
  end

  def describe(map)
    map.transform_keys do |key|
      label = TRANSLATIONS[key.to_sym]
      label ? "#{key} (#{label})" : key
    end
  end

  run! if $PROGRAM_NAME == __FILE__
end
