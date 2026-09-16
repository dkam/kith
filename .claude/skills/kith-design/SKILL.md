---
name: kith-design
description: Use this skill to generate well-branded interfaces and assets for Kith, either for production or throwaway prototypes/mocks/etc. Contains essential design guidelines, colors, type, fonts, assets, and UI kit components for prototyping.
user-invocable: true
---

Read `readme.md` in this directory, and explore the other available files.

In this repository the system is already implemented: the tokens live in
`app/assets/tailwind/application.css` and the shared classes (`.btn`,
`.btn-quiet`, `.btn-plain`, `.field`, `.label`, `.micro`, `.choice`, `.avatar`,
`.unread-dot`, `.pill`, `.post-title`, `.prose-kith`, `.comment-body`,
`.alert`, `.notice`) are defined there with `@apply`. Extend those rather than
adding a parallel set of utilities to a view.

If creating visual artifacts (slides, mocks, throwaway prototypes), copy the
token files out and write static HTML. The full system — component sheets, all
eight screens at both breakpoints, and the foundation specimen cards — is at
https://claude.ai/design/p/583cab02-8cc9-4721-8b58-b16d1cf1b09b

If the user invokes this skill without any other guidance, ask them what they
want to build or design, ask some questions, and act as an expert designer.
