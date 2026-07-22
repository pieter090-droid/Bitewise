# Bitewise branding - editorial premium

Status: approved for the test version on 2026-07-22. This document and
`assets/branding/brand_tokens.json` are the source of truth for future UI work.

## Brand idea

Bitewise helps people make better everyday food choices without diet pressure.
The interface should communicate calm authority: warm, precise, evidence-led and
never clinical or judgmental.

## Marks

- Bitewise uses a `BW` mark: the `B` plus a `W` made from two interlocking checks.
- SnackSwap uses a related `SW` mark: the `S` plus exactly the same check-based `W`.
- In both written wordmarks, the normal `w` is replaced by the double-check form.
- The left check is navy; the right check is gold.
- Code-native implementations live in `lib/core/branding/brand_marks.dart`.

## Palette

| Token | Value | Use |
| --- | --- | --- |
| Navy | `#062B52` | Identity, primary actions and important text |
| Gold | `#C99A3D` | Brand accent and deliberate action |
| Cream | `#FAF7F0` | Main background |
| Sage | `#6D8E5D` | Verified improvement only |
| Ink | `#18324B` | Body text |
| Slate | `#667789` | Secondary text |
| Hairline | `#E8E0D4` | Dividers and quiet borders |

## Typography and layout

- Editorial serif (Georgia fallback) for brand, major headings, product names and outcomes.
- System sans-serif for controls, labels and nutrition data.
- Prefer whitespace and hairlines over stacked elevated cards.
- Default card radius: 12 px. Control radius: 10 px. Minimum target: 44 px.
- Gold is sparse; sage must never imply an improvement that data does not support.

## Product presentation without images

The product database does not guarantee images. A product card therefore never
reserves an empty image box and never invents photography. Recognition order:

1. product name;
2. brand;
3. category or family;
4. barcode and comparison basis;
5. nutrition values.

## Functional guardrail

Branding work may change composition and presentation only. Barcode lookup,
classification, swap candidate selection, scoring, logging, feedback, history and
Supabase behavior must remain unchanged and are protected by the existing tests.
