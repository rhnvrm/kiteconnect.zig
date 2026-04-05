# Architecture

The library is organized into:
- a core client/configuration layer
- shared transport and error handling
- endpoint-family modules
- a parser-first ticker subsystem with a separate session/runtime layer

This split is intended to preserve protocol fidelity while keeping the implementation testable with fixtures and mock infrastructure.
