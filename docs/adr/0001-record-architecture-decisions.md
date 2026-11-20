# 1. Record architecture decisions

Date: 2026-11-21

## Status

Accepted

## Context

This repository packages two applications for Kubernetes. Several choices here (chart layout, how stateful
dependencies run, how deployments are driven) are not obvious from the YAML alone, and a reader should be able
to see why they were made and what was given up.

## Decision

Record significant decisions as short Architecture Decision Records in `docs/adr/`, numbered in order, using
the Nygard format (Context, Decision, Consequences). Superseded records stay in place and are marked as such.

## Consequences

- Each ADR is small enough to write in the same change as the decision.
- Reviewers can disagree with a specific record rather than with the whole repository.
