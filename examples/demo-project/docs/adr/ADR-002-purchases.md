# One-time unlock with StoreKit 2

Status: accepted. Implements D006.

## Context
Sharing collections (E2-S2) is the only paid feature. No subscriptions, no ads.

## Decision
A single non-consumable StoreKit 2 product. The unlock state is read from the device's
transactions, never from our own server (there is none, see D004).

## Consequences
Restoring purchases is free and automatic. Family Sharing is on.
