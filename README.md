# JWT Display Server

A basic Sinatra server to parse, validate, and display JWTs, suitable for use behind an [oauth2-proxy](https://oauth2-proxy.github.io/oauth2-proxy/).

## Running Locally

To run just the Sinatra app directly

    $ ruby ./server.rb

In this case, you will need to provide a valid JWT in the `X-Forwarded-Access-Token` header.

To run the server behind an oauth2-proxy

    $ cp sample.env .env
    # Provision an OIDC client and update .env with valid settings
    $ docker-compose up
