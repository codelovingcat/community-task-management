const test = require('node:test');
const assert = require('node:assert/strict');
const { renderTemplate, renderSubject, normalizeTemplateParams } = require('../dist/templateEngine.js');

test('renders placeholders with and without surrounding whitespace', () => {
  assert.equal(
    renderTemplate('<p>Hello {{ member_name }} — {{birthday_person}}</p>', {
      member_name: 'Gülben',
      birthday_person: 'Deniz'
    }),
    '<p>Hello Gülben — Deniz</p>'
  );
});

test('normalizes null values to empty strings and non-string values to strings', () => {
  assert.deepEqual(normalizeTemplateParams({
    member_name: 'Gülben',
    optional: null,
    count: 3
  }), {
    member_name: 'Gülben',
    optional: '',
    count: '3'
  });
});

test('renders unknown placeholders as empty instead of leaking raw tokens', () => {
  assert.equal(renderSubject('Hello {{member_name}} {{missing_value}}', { member_name: 'Ada' }), 'Hello Ada ');
});
