import tseslint from 'typescript-eslint';
import reactHooks from 'eslint-plugin-react-hooks';

// Keep the first lint gate focused on correctness; TypeScript's strict check
// continues to cover types and unused variables across the application.
export default [
  { ignores: ['dist/**', 'node_modules/**', 'email-worker/**'] },
  {
    files: ['src/**/*.{js,jsx,ts,tsx}', 'api/**/*.js', 'apps/member-portal/src/**/*.{ts,tsx}'],
    plugins: { 'react-hooks': reactHooks, '@typescript-eslint': tseslint.plugin },
    linterOptions: { reportUnusedDisableDirectives: 'off' },
    languageOptions: { parser: tseslint.parser, ecmaVersion: 'latest', sourceType: 'module', parserOptions: { ecmaFeatures: { jsx: true } } },
    rules: {
      'no-debugger': 'error',
      'no-dupe-args': 'error',
      'no-dupe-else-if': 'error',
      'no-duplicate-case': 'error',
      'no-unsafe-finally': 'error',
      'valid-typeof': 'error',
      'react-hooks/rules-of-hooks': 'error',
    },
  },
];
