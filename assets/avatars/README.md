# Player-specific portraits

PlayerAvatar resolves `PlayerPortraitCatalog.assets[player.id]`. No hash,
name matching, country-based selection, or arbitrary legacy `avatarKey` fallback
is used. An unknown ID or failed image decode displays a neutral person icon.
Players without portraits remain fully available in every game mode.

## Pack v1

| V4 player ID | Database name | Bundled file |
| --- | --- | --- |
| 8198 | Cristiano Ronaldo | portraits_v1/p_8198.webp |

384 × 384 WebP, quality 88, local/offline. The original was generated using the
built-in image-generation tool on 2026-09-27 (Europe/Istanbul), then resized and
encoded for the app. This is an AI-generated stylized likeness, not a photograph.

Final generation prompt:

> Use case: stylized-concept. Asset type: square portrait avatar for a football mobile game, one real named footballer. Primary request: A clearly recognizable likeness of Cristiano Ronaldo, accurate distinctive facial structure and recognizable signature hairstyle, facial hair and expression. Premium editorial comic illustration with crisp ink contours, natural anatomy, restrained cel shading, subtle facial detail, like a polished football sticker portrait. Front facing centered full head and upper shoulders, all hair visible with 8% top margin, face occupies most of square and reads at 48px. Plain unbranded deep teal sports shirt, flat pale sage background. No text, lettering, logos, watermarks, card borders, other people or montage. Depict the actual footballer, not a generic fictional substitute.

## Extending the pack

1. Verify the subject's exact ID, country and career in the V4 database. Do not
   match by name alone: the bundled `Burak Yilmaz` (164148, Austria) is not the
   Turkish international intended in the initial brief.
2. Review the portrait's likeness and small-size readability.
3. Save a square 384px WebP under this versioned directory and add its explicit
   ID/path mapping to `lib/data/player_portrait_catalog.dart`.
4. Run `flutter test test/visual_identity_test.dart`. The decode test checks every
   catalogued portrait. Verify added IDs against the SQLite database as well.

The initial five-player proposal is NOT complete. Ronaldo was generated;
Messi generation was rejected by the image tool with `moderation_blocked` /
`public-figure`. Falcao, Osimhen and Demiral were not generated after this block.
The catalog deliberately includes only the available, reviewed portrait.
