# Changelog

## Unreleased
- Orders can be cancelled while pending (`POST /orders/{id}/cancel`); cancelled orders are hidden from `GET /orders` by default.

## 1.0.0
- Orders: create, list, fetch, pay.
