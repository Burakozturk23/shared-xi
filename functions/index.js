/**
 * Shared XI / Linkball Cloud Functions
 * Şimdilik iskelet — matchmaking ileride buraya taşınabilir.
 */

const {setGlobalOptions} = require("firebase-functions");

// Maliyet kontrolü: eşzamanlı instance limiti
setGlobalOptions({maxInstances: 10});

// Örnek (kapalı). Deploy için en az bir export gerekmez;
// boş iskelet de deploy edilebilir.
//
// const {onRequest} = require("firebase-functions/https");
// const logger = require("firebase-functions/logger");
// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });
