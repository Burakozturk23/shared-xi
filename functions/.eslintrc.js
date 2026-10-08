module.exports = {
  env: {
    es6: true,
    node: true,
  },
  parserOptions: {
    ecmaVersion: 2022,
  },
  extends: [
    "eslint:recommended",
    "google",
  ],
  rules: {
    // CRLF is common in Windows working trees; do not fail lint over EOLs.
    // Git enforces LF for Functions source via .gitattributes.
    "linebreak-style": "off",
    "no-restricted-globals": ["error", "name", "length"],
    "prefer-arrow-callback": "error",
    "quotes": ["error", "double", {"allowTemplateLiterals": true}],
    "max-len": ["error", {"code": 120}],
    "require-jsdoc": "off",
    "valid-jsdoc": "off",
  },
  overrides: [
    {
      files: ["**/*.spec.*"],
      env: {
        mocha: true,
      },
      rules: {},
    },
  ],
  globals: {},
};
