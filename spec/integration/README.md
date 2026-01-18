# Integration Tests

This directory contains integration tests that make real network calls to the Onetime Secret API.

## Running Integration Tests

To run only the integration tests:

```bash
bundle exec rspec spec/integration --tag integration
```

To run all tests (unit + integration):

```bash
bundle exec rspec
```

To exclude integration tests and run only unit tests:

```bash
bundle exec rspec --tag ~integration
```

## Configuration

### Anonymous Access
By default, integration tests will use anonymous API access if no credentials are provided.

### Authenticated Access
To test with authenticated API access, set these environment variables:

```bash
export ONETIME_CUSTID="your@email.com"
export ONETIME_APIKEY="your_api_key"
bundle exec rspec spec/integration --tag integration
```

### Custom Host
To test against a custom Onetime Secret instance:

```bash
export ONETIME_HOST="https://your-instance.com/api"
bundle exec rspec spec/integration --tag integration
```

## Test Coverage

The integration test suite covers:

- **Secret workflow**: Create and retrieve secrets
- **Passphrase protection**: Create secrets with passphrases
- **TTL (Time-to-Live)**: Create secrets with expiration times
- **Metadata**: Retrieve and track secret metadata
- **State tracking**: Verify secret state changes (new -> received)
- **Generate**: Generate random secrets
- **Status**: Check service status

## Notes

- Integration tests use real network calls and create actual secrets on the API
- Secrets are burned (deleted) after retrieval as part of the normal workflow
- Tests are idempotent and can be run multiple times
- WebMock is disabled for integration tests to allow real HTTP connections
