# Onetime-up

Fork of the Ruby program [`One-Time Secret`](https://github.com/onetimesecret/onetime-ruby), using the API v2.

## Basic usage

Share a secret:

```sh
echo "secret text" | onetime share
```

Share a secret protected by a passphrase:

```sh
echo "secret text" | onetime share -p "shared-passphrase"
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
