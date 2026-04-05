# Endpoints

This directory will hold REST endpoint-family modules such as user, margins, orders, portfolio, market, GTT, mutual funds, and alerts.

## Coordination note
Shared helpers should not be introduced here ad hoc if they are likely to be reused across multiple endpoint families. Land shared abstractions via bosun first.
