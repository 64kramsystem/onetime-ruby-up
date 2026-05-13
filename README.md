# Onetime-up

Fork of the Ruby program [`One-Time Secret`](https://github.com/onetimesecret/onetime-ruby), using the API v2, with the following improvements:

- CLI built on Ruby stdlib — no third-party CLI dependency (the upstream `drydock` requirement has been removed)
- Uses the API v2 (response shapes updated accordingly)
- `share` accepts a positional file path (e.g. `onetime share /path/to/file`) in addition to stdin redirection
- `generate` rejects misuse (extra positional args, piped stdin) with a clear hint pointing at `onetime share`
- Default API host is `https://eu.onetimesecret.com/api`
- The `metadata` command is renamed `receipt` for consistency with the API

## Basic usage

Share a secret:

```sh
echo "secret text" | onetime share
# Share a secret protected by a passphrase:
echo "secret text" | onetime share -p "shared-passphrase"
# Share the contents of a local file:
onetime share /path/to/file
```

Retrieve a secret:

```sh
onetime secret SECRET_KEY
```

Generate a random secret:

```sh
onetime generate
```

Use JSON or YAML output:

```sh
onetime -j generate
onetime -y receipt RECEIPT_KEY
```

## Breaking changes

The command `metadata` has been renamed `receipt` for consistency with the API.

The default API host is now `https://eu.onetimesecret.com/api`.

The library now uses API v2 response shapes. Programmatic callers should read receipt data from `record.receipt` and secret data from `record.secret` or reveal responses from `record.secret_value`.

The `generate` command now rejects extra positional arguments and piped stdin (previously both were silently ignored). Use `onetime share` to share file contents or piped data.
