module.exports = {
  extends: [
    'airbnb-base/legacy',
    'prettier',
    'plugin:vue/vue3-recommended',
    'plugin:vitest-globals/recommended',
    // use recommended-legacy when upgrading the plugin to v4
    'plugin:@intlify/vue-i18n/recommended',
  ],
  overrides: [
    {
      files: ['**/*.spec.{j,t}s?(x)'],
      env: {
        'vitest-globals/env': true,
      },
    },
    {
      files: ['**/*.story.vue'],
      rules: {
        'vue/no-undef-components': [
          'error',
          {
            ignorePatterns: ['Variant', 'Story'],
          },
        ],
        // Story files can have static strings, it doesn't need to handle i18n always.
        'vue/no-bare-strings-in-template': 'off',
        'no-console': 'off',
        // Stories are dev-only component playgrounds, not shipped UI.
        'vuejs-accessibility/form-control-has-label': 'off',
      },
    },
  ],
  plugins: ['html', 'prettier', 'vuejs-accessibility'],
  parserOptions: {
    ecmaVersion: 'latest',
    sourceType: 'module',
  },
  rules: {
    'prettier/prettier': ['error'],
    camelcase: 'off',
    'no-param-reassign': 'off',
    'import/no-extraneous-dependencies': 'off',
    'import/prefer-default-export': 'off',
    'import/no-named-as-default': 'off',
    'jsx-a11y/no-static-element-interactions': 'off',
    'jsx-a11y/click-events-have-key-events': 'off',
    'jsx-a11y/label-has-associated-control': 'off',
    'jsx-a11y/label-has-for': 'off',
    'jsx-a11y/anchor-is-valid': 'off',
    // Accessibility linting (Vue templates). Curated high-signal rules in
    // `warn` mode so they surface issues without failing CI on the existing
    // backlog. Noisy interaction rules are intentionally left off for now.
    'vuejs-accessibility/alt-text': 'warn',
    'vuejs-accessibility/anchor-has-content': 'warn',
    'vuejs-accessibility/aria-props': 'warn',
    'vuejs-accessibility/aria-role': 'warn',
    'vuejs-accessibility/aria-unsupported-elements': 'warn',
    'vuejs-accessibility/role-has-required-aria-props': 'warn',
    'vuejs-accessibility/no-redundant-roles': 'warn',
    'vuejs-accessibility/form-control-has-label': 'warn',
    'vuejs-accessibility/heading-has-content': 'warn',
    'vuejs-accessibility/iframe-has-title': 'warn',
    'vuejs-accessibility/no-autofocus': 'warn',
    'vuejs-accessibility/tabindex-no-positive': 'warn',
    'vuejs-accessibility/click-events-have-key-events': 'off',
    'vuejs-accessibility/mouse-events-have-key-events': 'off',
    'vuejs-accessibility/no-static-element-interactions': 'off',
    'vuejs-accessibility/label-has-for': 'off',
    'vuejs-accessibility/media-has-caption': 'off',
    'vuejs-accessibility/interactive-supports-focus': 'off',
    'import/no-unresolved': 'off',
    'vue/html-indent': 'off',
    'vue/multi-word-component-names': 'off',
    'vue/next-tick-style': ['error', 'callback'],
    'vue/block-order': [
      'error',
      {
        order: ['script', 'template', 'style'],
      },
    ],
    'vue/component-name-in-template-casing': [
      'error',
      'PascalCase',
      {
        registeredComponentsOnly: true,
      },
    ],
    'vue/component-options-name-casing': ['error', 'PascalCase'],
    'vue/custom-event-name-casing': ['error', 'camelCase'],
    'vue/define-emits-declaration': ['error'],
    'vue/define-macros-order': [
      'error',
      {
        order: ['defineProps', 'defineEmits'],
        defineExposeLast: false,
      },
    ],
    'vue/define-props-declaration': ['error', 'runtime'],
    'vue/match-component-import-name': ['error'],
    'vue/no-bare-strings-in-template': [
      'error',
      {
        allowlist: [
          '(',
          ')',
          ',',
          '.',
          '&',
          '+',
          '-',
          '=',
          '*',
          '/',
          '#',
          '%',
          '!',
          '?',
          ':',
          '[',
          ']',
          '{',
          '}',
          '<',
          '>',
          '⌘',
          '📄',
          '🎉',
          '🚀',
          '💬',
          '👥',
          '📥',
          '🔖',
          '❌',
          '✅',
          '\u00b7',
          '\u2022',
          '\u2010',
          '\u2013',
          '\u2014',
          '\u2212',
          '|',
        ],
        attributes: {
          '/.+/': [
            'title',
            'aria-label',
            'aria-placeholder',
            'aria-roledescription',
            'aria-valuetext',
          ],
          input: ['placeholder'],
        },
        directives: ['v-text'],
      },
    ],
    'vue/no-empty-component-block': 'error',
    'vue/no-multiple-objects-in-class': 'error',
    'vue/no-root-v-if': 'warn',
    'vue/no-static-inline-styles': [
      'error',
      {
        allowBinding: false,
      },
    ],
    'vue/no-template-target-blank': [
      'error',
      {
        allowReferrer: false,
        enforceDynamicLinks: 'always',
      },
    ],
    'vue/no-required-prop-with-default': [
      'error',
      {
        autofix: false,
      },
    ],
    'vue/no-this-in-before-route-enter': 'error',
    'vue/no-undef-components': [
      'error',
      {
        ignorePatterns: [
          '^woot-',
          '^fluent-',
          '^multiselect',
          '^router-link',
          '^router-view',
          '^ninja-keys',
          '^FormulateForm',
          '^FormulateInput',
          '^highlightjs',
        ],
      },
    ],
    'vue/no-unused-emit-declarations': 'error',
    'vue/no-unused-refs': 'error',
    'vue/no-use-v-else-with-v-for': 'error',
    'vue/prefer-true-attribute-shorthand': 'error',
    'vue/no-useless-v-bind': [
      'error',
      {
        ignoreIncludesComment: false,
        ignoreStringEscape: false,
      },
    ],
    'vue/no-v-text': 'error',
    'vue/padding-line-between-blocks': ['error', 'always'],
    'vue/prefer-separate-static-class': 'error',
    'vue/require-explicit-slots': 'error',
    'vue/require-macro-variable-name': [
      'error',
      {
        defineProps: 'props',
        defineEmits: 'emit',
        defineSlots: 'slots',
        useSlots: 'slots',
        useAttrs: 'attrs',
      },
    ],
    'vue/no-unused-properties': [
      'error',
      {
        groups: ['props'],
        deepData: false,
        ignorePublicMembers: false,
        unreferencedOptions: [],
      },
    ],
    'vue/max-attributes-per-line': [
      'error',
      {
        singleline: {
          max: 20,
        },
        multiline: {
          max: 1,
        },
      },
    ],
    'vue/html-self-closing': [
      'error',
      {
        html: {
          void: 'always',
          normal: 'always',
          component: 'always',
        },
        svg: 'always',
        math: 'always',
      },
    ],
    'vue/no-v-html': 'off',
    'vue/component-definition-name-casing': 'off',
    'vue/singleline-html-element-content-newline': 'off',
    'import/extensions': ['off'],
    'no-console': 'error',
    '@intlify/vue-i18n/no-dynamic-keys': 'warn',
    '@intlify/vue-i18n/no-unused-keys': [
      'warn',
      {
        extensions: ['.js', '.vue'],
      },
    ],
  },
  settings: {
    'vue-i18n': {
      localeDir: './app/javascript/*/i18n/**.json',
    },
  },
  env: {
    browser: true,
    node: true,
  },
  globals: {
    bus: true,
    vi: true,
  },
};
