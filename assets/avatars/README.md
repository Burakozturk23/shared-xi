# Player visuals

PlayerAvatar now renders a symbolic kit using Flutter CustomPainter. No portrait
assets, avatarKey lookup, network calls or per-player image generation are used.
The previous portrait experiment is superseded by this design.

PlayerKitIdentity supplies name initials and position colors. Kits below 64px
show only the shirt and initials; 64px and larger add a local emoji flag and a
position abbreviation. Unknown positions use a neutral palette; empty names use
?. Full name, position and countries remain available to screen readers.

Colors: Goalkeeper amber, Defender cyan, Midfield green, Attack lavender.
A symbolic shirt does not represent a current club kit or squad number.
Emoji flag rendering depends on the device font; unsupported countries use the
existing neutral flag fallback. No flag image is downloaded by PlayerAvatar.

See docs/design/player-kit-preview.svg for a vector design preview (not a
Flutter screenshot). Widget tests cover 28/34/48/64/96px and 3x system text.
Flutter execution remains unverified: the earlier normal and offline dependency
setup was blocked by automatic review because it requested a cloud metadata
endpoint. No further attempt was made to bypass that block.
