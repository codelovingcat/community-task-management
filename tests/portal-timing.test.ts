import test from 'node:test';
import assert from 'node:assert/strict';
import { taskTiming, taskSummary, formatTaskDate } from '../apps/member-portal/src/taskTiming';
import type { PortalTask } from '../apps/member-portal/src/types';
const now = Date.parse('2026-11-13T09:00:00Z');
const make = (remaining: number, status = 'backlog'): PortalTask => ({ id: 't', title: 'Task', status, deadline: new Date(now + remaining).toISOString() });
const hour = 3600000;
test('deadline boundaries include backlog tasks and do not become overdue early', () => {
  for (const [ms, kind] of [[73*hour,'scheduled'],[72*hour,'soon'],[24*hour+1,'soon'],[24*hour,'urgent'],[0,'urgent'],[-1,'overdue']] as const) {
    assert.equal(taskTiming(make(ms), now).kind, kind);
  }
  assert.equal(taskTiming({ ...make(0), deadline: null }, now).kind, 'undated');
  assert.equal(taskTiming({ ...make(0), deadline: 'invalid' }, now).kind, 'invalid');
  assert.equal(taskTiming(make(-1, 'unexpected'), now).kind, 'unknownStatus');
});
test('completion uses recorded completion time, never updated_at or current time', () => {
  const task = make(-hour, 'completed');
  assert.equal(taskTiming(task, now).kind, 'completedUnknown');
  assert.equal(taskTiming({ ...task, completed_at: task.deadline }, now).kind, 'onTime');
  assert.equal(taskTiming({ ...task, status: 'done', completed_at: new Date(now).toISOString() }, now).kind, 'late');
  assert.equal(taskTiming({ ...task, completed_at: 'invalid' }, now).kind, 'completedUnknown');
  assert.equal(taskTiming({ ...task, deadline: null, completed_at: new Date(now).toISOString() }, now).kind, 'completedUnknown');
});
test('chart buckets partition tasks without counting late completed tasks as active overdue', () => {
  assert.deepEqual(taskSummary([],now),{total:0,complete:0,overdue:0,active:0,other:0});
  assert.deepEqual(taskSummary([make(-1),make(hour),make(-hour,'done')],now),{total:3,complete:1,overdue:1,active:2,other:1});
  assert.match(formatTaskDate('2026-11-13T09:00:00Z'), /12:00/);
  assert.equal(formatTaskDate('invalid'), '—');
});
