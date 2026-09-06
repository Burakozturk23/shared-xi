# Step 06A — Android production identity

Production package: `com.burakozturk.linkball`

This phase is designed to close:

- R01 placeholder applicationId
- R02 API 36 ambiguity
- R03 debug release signing

The Firebase registration step updates only the Android Firebase app/config so
existing Web/iOS/macOS/Windows options are preserved.

The upload signing certificate fingerprints generated here are inputs for the
next phase: Firebase App Check with Play Integrity.
