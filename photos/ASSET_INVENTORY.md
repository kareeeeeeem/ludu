# Visual reference inventory

The requested `photots` directory is absent. These seven files were found in `photos` and visually inspected on 2026-10-15. All are RGB JPEGs with **no alpha transparency**. They contain third-party game branding or composite reference layouts. They are **not bundled in the app**; commercial reuse requires license verification. The app uses an original generated hero illustration and code-drawn board, pieces, and dice.

| File in `photos/` | Size | Content | Recommended use | Standalone? |
|---|---:|---|---|---|
| `WhatsApp Image 2026-10-13 at 06.03.04.jpeg` | 899×1599 | Branded screenshot of a colorful four-player Ludo board and HUD | Layout and palette reference | No, screenshot |
| `WhatsApp Image 2026-10-13 at 06.03.04 (1).jpeg` | 1599×899 | Blue themed soccer, chess, animal, vehicle and other token collage with logo | Gloss/material and silhouette reference | No, branded collage on gray background |
| `WhatsApp Image 2026-10-13 at 06.03.05.jpeg` | 1599×899 | Ten illustrated dice styles with logo | Dice shape and finish reference | No, branded collage on gray background |
| `WhatsApp Image 2026-10-13 at 06.03.06.jpeg` | 1599×899 | Axe, ice cream, soccer and classic piece color variants with logo | Token variety reference | No, branded collage on gray background |
| `WhatsApp Image 2026-10-13 at 06.04.10.jpeg` | 1599×1142 | Concept sheet with a stylized vendor cart and sketch | Illustration style reference | No, sheet on parchment and dark panels |
| `WhatsApp Image 2026-10-13 at 06.04.11.jpeg` | 1599×1142 | Concept sheet with a travel bench and bird sketch | Illustration style reference | No, sheet on parchment and dark panels |
| `WhatsApp Image 2026-10-13 at 06.04.11 (1).jpeg` | 1599×1378 | Multiple decorative environment props including cart, flowers, bench | Environmental style reference | No, collage on dark background |

Individual objects could be segmented only through manual masking and reconstruction. JPEG edge compression and surrounding gray/panel backgrounds make direct rectangular cropping unsuitable for production transparent pieces. No extracted artwork has been shipped.

## Original app asset

`frontend/assets/illustrations/ludo_hero.png`: 1254×1254 RGBA PNG, original generated isometric Ludo illustration for the home screen. Prompt: “Original transparent-background isometric 3D cartoon four-color Ludo board with glossy classic pieces and ivory die, rounded bevelled edges, warm highlights, no text or logo.” Generated with the built-in imagegen tool. It is decorative only; gameplay geometry is code-drawn.
