"""Tests for random event detection and table sampling."""

from mythic.events import (
    is_random_event,
    EVENT_FOCUS_TABLE,
    ACTION_TABLE,
    SUBJECT_TABLE,
    sample_event,
)


def test_doubles_below_cf_triggers():
    assert is_random_event(roll=11, chaos_factor=5) is True
    assert is_random_event(roll=33, chaos_factor=5) is True
    assert is_random_event(roll=55, chaos_factor=5) is True


def test_doubles_above_cf_does_not_trigger():
    assert is_random_event(roll=66, chaos_factor=5) is False
    assert is_random_event(roll=99, chaos_factor=5) is False


def test_non_doubles_does_not_trigger():
    assert is_random_event(roll=12, chaos_factor=5) is False
    assert is_random_event(roll=43, chaos_factor=5) is False


def test_event_tables_populated():
    assert len(EVENT_FOCUS_TABLE) > 0
    assert len(ACTION_TABLE) > 0
    assert len(SUBJECT_TABLE) > 0
    # Highest threshold of each table should be 100.
    assert EVENT_FOCUS_TABLE[-1][0] == 100
    assert ACTION_TABLE[-1][0] == 100
    assert SUBJECT_TABLE[-1][0] == 100


def test_sample_event_returns_focus_action_subject():
    event = sample_event()
    assert "focus" in event
    assert "action" in event
    assert "subject" in event
    # Each component should be a non-empty string.
    assert event["focus"] and isinstance(event["focus"], str)
    assert event["action"] and isinstance(event["action"], str)
    assert event["subject"] and isinstance(event["subject"], str)
