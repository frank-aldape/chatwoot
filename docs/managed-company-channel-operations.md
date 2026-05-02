# Managed Company Channel Operations

## Purpose

This workflow defines how to operate inbox provisioning for a customer company inside a single Chatwoot account using `ManagedCompany`, `Inbox`, and `Team` permissions.

## Operational model

- A `ManagedCompany` groups inboxes that belong to the same customer company.
- A company can have multiple inboxes, one per contracted channel.
- Access is never granted by company alone.
- Access is granted by `Team -> Inbox` or by direct inbox membership.

## Supported channel strategy

### Native flows

Use these when Chatwoot already supports the provider directly:

- WhatsApp
- Facebook / Messenger
- Instagram
- Email
- Website

### LinkedIn flow

LinkedIn is not a native Chatwoot inbox provider in this codebase.

Use the dedicated `LinkedIn` option in inbox creation. It provisions an inbox through the `API Channel` flow so each company can still have a formal LinkedIn inbox with standard naming and permissions.

This inbox is intended to be connected through your own middleware or provider.

## Channel load control per company

To avoid unnecessary operational overload, a single `ManagedCompany` may only have one active inbox for each core social slot:

- `WhatsApp`
- `Facebook / Messenger`
- `Instagram`
- `LinkedIn`

This means the system blocks duplicates such as:

- two WhatsApp inboxes for the same company
- two Messenger inboxes for the same company
- two Instagram inboxes for the same company
- two LinkedIn bridge inboxes for the same company

Channels that may legitimately exist more than once per company are still allowed, for example:

- multiple `Email` inboxes under the same authorized domain
- multiple `API` inboxes for custom integrations other than the dedicated LinkedIn bridge
- additional `Website` or internal operational inboxes when needed

## Provisioning checklist per company

1. Create the `ManagedCompany`.
2. Set the `authorized_domain`.
3. Create one inbox per active channel.
4. Link each inbox to the company during creation.
5. Use the naming convention:

`[COMPANY] - [CHANNEL] - [FUNCTION]`

Examples:

- `ADEMEX - WhatsApp - Ventas`
- `ADEMEX - Messenger - Atención`
- `ADEMEX - Instagram - Marketing`
- `ADEMEX - LinkedIn - Prospectación`
- `ADEMEX - Email - Soporte`

6. Assign access through teams only to the inboxes they should handle.

## Permissions

- A team may operate multiple companies.
- A company may have multiple inboxes.
- A team does not automatically see every inbox inside a company.
- A team only sees the specific inboxes assigned to it.

## Email domain rule

For email inboxes, Chatwoot only validates that the email domain matches the `authorized_domain` configured in the company record.

There is no DNS, SPF, or DKIM validation in this workflow.
